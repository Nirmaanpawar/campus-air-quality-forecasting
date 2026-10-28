#!/usr/bin/env Rscript
# ==============================================================================
# Campus Air Quality Monitoring, Analysis & Forecasting 2026
# End-to-End Analytics Pipeline: Cleaning, EDA, Stationarity, ARIMA & SARIMAX
# ==============================================================================

suppressPackageStartupMessages({
  library(forecast)
  library(zoo)
  library(dplyr)
  library(tseries)
  library(ggplot2)
})

cat("====================================================================\n")
cat("Starting Campus Air Quality Analytics & Forecasting Pipeline\n")
cat("====================================================================\n\n")

# ------------------------------------------------------------------------------
# 1. LOAD DATASETS
# ------------------------------------------------------------------------------
cat("[1/6] Loading raw time-series datasets...\n")
raw_data_2025 <- read.csv("campus_air_quality_hourly_2025.csv", stringsAsFactors = FALSE)
raw_data_2026 <- read.csv("campus_air_quality_hourly_2026_test.csv", stringsAsFactors = FALSE)

raw_data_2025$Timestamp <- as.POSIXct(raw_data_2025$Timestamp, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
raw_data_2026$Timestamp <- as.POSIXct(raw_data_2026$Timestamp, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")

cat(sprintf("   - 2025 Training Records: %d\n", nrow(raw_data_2025)))
cat(sprintf("   - 2026 Evaluation Records: %d\n", nrow(raw_data_2026)))

# ------------------------------------------------------------------------------
# 2. DATA CLEANING & IMPUTATION
# ------------------------------------------------------------------------------
cat("\n[2/6] Executing Data Cleaning & Time-Series Imputation...\n")

clean_dataset <- function(df) {
  # 1. Detect sensor saturation anomalies (> 500 ug/m3)
  outlier_idx <- which(df$PM2.5..ug.m3. > 500 | df$PM2.5..ug.m3. < 0)
  num_outliers <- length(outlier_idx)
  df$PM2.5..ug.m3.[outlier_idx] <- NA
  
  # 2. Count missing packets
  na_pm25 <- sum(is.na(df$PM2.5..ug.m3.))
  na_co2 <- sum(is.na(df$CO2..ppm.))
  na_nox <- sum(is.na(df$NOx..ppb.))
  
  cat(sprintf("   - Outliers flagged (>500 ug/m3): %d\n", num_outliers))
  cat(sprintf("   - Missing values detected: PM2.5=%d, CO2=%d, NOx=%d\n", na_pm25, na_co2, na_nox))
  
  # 3. Impute missing values per location using time-series linear interpolation
  df_clean <- df %>%
    group_by(Location) %>%
    arrange(Timestamp) %>%
    mutate(
      PM2.5_clean = na.approx(PM2.5..ug.m3., rule = 2),
      CO2_clean = na.approx(CO2..ppm., rule = 2),
      NOx_clean = na.approx(NOx..ppb., rule = 2)
    ) %>%
    ungroup()
  
  # 4. Calculate 24-hour moving average
  df_clean <- df_clean %>%
    group_by(Location) %>%
    arrange(Timestamp) %>%
    mutate(
      PM2.5_24h_MA = round(rollapply(PM2.5_clean, width = 24, FUN = mean, align = "right", fill = NA), 1)
    ) %>%
    ungroup()
  
  return(df_clean)
}

data_2025_clean <- clean_dataset(raw_data_2025)
data_2026_clean <- clean_dataset(raw_data_2026)

# ------------------------------------------------------------------------------
# 3. EXPLORATORY DATA ANALYSIS (EDA) & CORRELATION METRICS
# ------------------------------------------------------------------------------
cat("\n[3/6] Performing Exploratory Data Analysis & Spatial Analytics...\n")

location_summary <- data_2025_clean %>%
  group_by(Location, Location_Type) %>%
  summarise(
    Mean_PM2.5 = round(mean(PM2.5_clean), 1),
    Max_PM2.5 = round(max(PM2.5_clean), 1),
    Pct95_PM2.5 = round(quantile(PM2.5_clean, 0.95), 1),
    Mean_CO2 = round(mean(CO2_clean), 0),
    Max_CO2 = round(max(CO2_clean), 0),
    Mean_NOx = round(mean(NOx_clean), 1),
    Hours_Exceeding_60 = sum(PM2.5_clean > 60),
    Hours_Exceeding_120 = sum(PM2.5_clean > 120),
    .groups = "drop"
  )

cat("\n--- Location Environmental Summary (2025) ---\n")
print(as.data.frame(location_summary))

# Key correlations
traffic_nox_cor <- cor(data_2025_clean$Vehicle_Count, data_2025_clean$NOx_clean)
traffic_pm_cor  <- cor(data_2025_clean$Vehicle_Count, data_2025_clean$PM2.5_clean)
lib_data <- filter(data_2025_clean, Location == "Library")
lib_foot_co2_cor <- cor(lib_data$Human_Footfall, lib_data$CO2_clean)

cat(sprintf("\nKey Physical Correlations:\n"))
cat(sprintf("   - Vehicle Count <-> NOx Correlation: %.3f (Strong Vehicle Combustion Link)\n", traffic_nox_cor))
cat(sprintf("   - Vehicle Count <-> PM2.5 Correlation: %.3f\n", traffic_pm_cor))
cat(sprintf("   - Library Footfall <-> CO2 Correlation: %.3f (Strong Respiration Accumulation)\n", lib_foot_co2_cor))

# ------------------------------------------------------------------------------
# 4. TIME-SERIES STATIONARITY TESTS & DECOMPOSITION
# ------------------------------------------------------------------------------
cat("\n[4/6] Conducting Time-Series Diagnostics (Main Gate Focus)...\n")

main_gate_train <- filter(data_2025_clean, Location == "Main Gate") %>% arrange(Timestamp)
main_gate_test  <- filter(data_2026_clean, Location == "Main Gate") %>% arrange(Timestamp)

# Build hourly time-series (frequency = 24 for daily periodicity)
ts_train_pm25 <- ts(main_gate_train$PM2.5_clean, frequency = 24)

# ADF Test
adf_result <- adf.test(ts_train_pm25)
cat(sprintf("   - Augmented Dickey-Fuller Test Statistic: %.3f (p-value: %.4f)\n", adf_result$statistic, adf_result$p.value))
if (adf_result$p.value < 0.05) {
  cat("     -> Series is stationary at 5% significance level.\n")
} else {
  cat("     -> Differencing is required.\n")
}

# ------------------------------------------------------------------------------
# 5. MODELING: ARIMA, SARIMA, & SARIMAX
# ------------------------------------------------------------------------------
cat("\n[5/6] Training & Benchmarking Models...\n")

# Use last 14 days of 2025 for training the forecast model to reflect current dynamics
recent_train <- tail(main_gate_train, 14 * 24)
ts_recent <- ts(recent_train$PM2.5_clean, frequency = 24)

# Benchmark Test Window: First 24 hours of 2026
test_24h <- head(main_gate_test, 24)
actual_24h <- test_24h$PM2.5_clean

# A. Model 1: Non-Seasonal ARIMA
cat("   - Fitting Model 1: Standard ARIMA...\n")
fit_arima <- auto.arima(ts_recent, seasonal = FALSE, stepwise = TRUE, max.p = 3, max.q = 3)
fc_arima <- forecast(fit_arima, h = 24)

# B. Model 2: Seasonal ARIMA (SARIMA) (captures 24h daily diurnal cycle)
cat("   - Fitting Model 2: Seasonal ARIMA (SARIMA s=24)...\n")
fit_sarima <- auto.arima(ts_recent, seasonal = TRUE, stepwise = TRUE, approximation = TRUE, max.p = 2, max.q = 2, max.P = 1, max.Q = 1)
fc_sarima <- forecast(fit_sarima, h = 24)

# C. Model 3: SARIMAX (with Exogenous Regressors: Vehicle_Count, Wind_Speed)
cat("   - Fitting Model 3: SARIMAX (with Exogenous Covariates)...\n")
xreg_train <- as.matrix(recent_train[, c("Vehicle_Count", "Wind_Speed..m.s.")])
xreg_test  <- as.matrix(test_24h[, c("Vehicle_Count", "Wind_Speed..m.s.")])

fit_sarimax <- auto.arima(ts_recent, xreg = xreg_train, seasonal = TRUE, stepwise = TRUE, approximation = TRUE, max.p = 2, max.q = 2, max.P = 1, max.Q = 1)
fc_sarimax <- forecast(fit_sarimax, xreg = xreg_test, h = 24)

# Evaluate Performance Metrics
calc_metrics <- function(actual, pred) {
  rmse <- sqrt(mean((actual - pred)^2))
  mae  <- mean(abs(actual - pred))
  mape <- mean(abs((actual - pred) / actual)) * 100
  return(c(RMSE = round(rmse, 2), MAE = round(mae, 2), MAPE_pct = round(mape, 2)))
}

m1_metrics <- calc_metrics(actual_24h, as.numeric(fc_arima$mean))
m2_metrics <- calc_metrics(actual_24h, as.numeric(fc_sarima$mean))
m3_metrics <- calc_metrics(actual_24h, as.numeric(fc_sarimax$mean))

performance_df <- data.frame(
  Model = c("ARIMA (Non-seasonal)", "SARIMA (Seasonal 24h)", "SARIMAX (Seasonal + Exogenous Traffic/Wind)"),
  Specification = c(as.character(fit_arima), as.character(fit_sarima), as.character(fit_sarimax)),
  RMSE = c(m1_metrics["RMSE"], m2_metrics["RMSE"], m3_metrics["RMSE"]),
  MAE  = c(m1_metrics["MAE"], m2_metrics["MAE"], m3_metrics["MAE"]),
  MAPE = c(m1_metrics["MAPE_pct"], m2_metrics["MAPE_pct"], m3_metrics["MAPE_pct"])
)

cat("\n--- Model Forecast Performance Comparison (24h Ahead Horizon) ---\n")
print(performance_df)

# Export Forecast Results for 24 hours
forecast_export <- data.frame(
  Forecast_Hour = 1:24,
  Timestamp = test_24h$Timestamp,
  Actual_PM2.5 = round(actual_24h, 1),
  SARIMA_Pred = round(as.numeric(fc_sarima$mean), 1),
  SARIMA_Lower_95 = round(as.numeric(fc_sarima$lower[, 2]), 1),
  SARIMA_Upper_95 = round(as.numeric(fc_sarima$upper[, 2]), 1),
  SARIMAX_Pred = round(as.numeric(fc_sarimax$mean), 1),
  SARIMAX_Lower_95 = round(as.numeric(fc_sarimax$lower[, 2]), 1),
  SARIMAX_Upper_95 = round(as.numeric(fc_sarimax$upper[, 2]), 1),
  Location = "Main Gate"
)

# ------------------------------------------------------------------------------
# 6. EXPORT POWER BI STAR-SCHEMA TABLES
# ------------------------------------------------------------------------------
cat("\n[6/6] Generating Power BI Data Model Tables...\n")

# 1. Fact Table (Cleaned Air Quality)
fact_table <- data_2025_clean %>%
  select(
    Timestamp, Location, Location_Type,
    PM2.5 = PM2.5_clean, PM2.5_24h_MA,
    CO2 = CO2_clean, NOx = NOx_clean,
    Temperature = Temperature..C.,
    Humidity = Relative_Humidity....,
    Wind_Speed = Wind_Speed..m.s.,
    Vehicle_Count, Human_Footfall,
    Event, AQI_Category
  )
write.csv(fact_table, "fact_air_quality_hourly.csv", row.names = FALSE)
cat("   -> Exported 'fact_air_quality_hourly.csv' (Clean Fact Table)\n")

# 2. Dim Location Table (Metadata & Coordinates for Mapping)
dim_location <- data.frame(
  Location = c("Main Gate", "Parking Lot", "Back Gate Entry 1", "Back Gate Entry 2", 
               "Library", "Canteen", "Hostel Area", "Playground"),
  Location_Type = c("Traffic Gate", "Parking Area", "Secondary Gate", "Secondary Gate",
                    "Indoor Study", "Indoor Dining", "Residential", "Outdoor Recreation"),
  Environment = c("Outdoor", "Outdoor", "Outdoor", "Outdoor", "Indoor", "Indoor", "Outdoor/Residential", "Outdoor"),
  Latitude = c(28.5450, 28.5442, 28.5495, 28.5488, 28.5465, 28.5458, 28.5480, 28.5472),
  Longitude = c(77.1920, 77.1910, 77.1960, 77.1975, 77.1935, 77.1945, 77.1950, 77.1925),
  Target_CO2_Threshold = c(500, 500, 500, 500, 1000, 1000, 800, 500),
  Target_PM25_Threshold = c(60, 60, 60, 60, 30, 45, 60, 60)
)
write.csv(dim_location, "dim_location.csv", row.names = FALSE)
cat("   -> Exported 'dim_location.csv' (Dimension Table with GPS coordinates)\n")

# 3. Dim Calendar Table
timestamps_seq <- seq(from = as.POSIXct("2025-01-01 00:00:00", tz="UTC"),
                      to   = as.POSIXct("2026-03-31 23:00:00", tz="UTC"), by = "hour")
dim_calendar <- data.frame(
  Timestamp = format(timestamps_seq, "%Y-%m-%d %H:%M:%S"),
  Date = format(timestamps_seq, "%Y-%m-%d"),
  Hour = as.integer(format(timestamps_seq, "%H")),
  Day_of_Week = weekdays(timestamps_seq),
  Month = format(timestamps_seq, "%B"),
  Month_Number = as.integer(format(timestamps_seq, "%m")),
  Year = as.integer(format(timestamps_seq, "%Y")),
  Is_Weekend = ifelse(weekdays(timestamps_seq) %in% c("Saturday", "Sunday"), "Weekend", "Weekday")
)
write.csv(dim_calendar, "dim_calendar.csv", row.names = FALSE)
cat("   -> Exported 'dim_calendar.csv' (Time Dimension)\n")

# 4. Forecast Fact Table
write.csv(forecast_export, "fact_forecast_24h.csv", row.names = FALSE)
cat("   -> Exported 'fact_forecast_24h.csv' (24-Hour Forecast Horizon)\n")

# 5. Model Performance Metrics Table
write.csv(performance_df, "model_performance_metrics.csv", row.names = FALSE)
cat("   -> Exported 'model_performance_metrics.csv' (Model Comparison Metrics)\n")

cat("\n====================================================================\n")
cat("Pipeline Completed Successfully! All deliverables generated.\n")
cat("====================================================================\n")
