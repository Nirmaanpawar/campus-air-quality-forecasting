#!/usr/bin/env Rscript
# ==============================================================================
# Predict Tomorrow's 24 Hours of Air Quality (PM2.5 & AQI) using SARIMAX
# ==============================================================================

suppressPackageStartupMessages({
  library(forecast)
  library(zoo)
  library(dplyr)
})

cat("====================================================================\n")
cat("      Campus Air Quality: 24-Hour Tomorrow Forecast Engine          \n")
cat("====================================================================\n\n")

# 1. Load historical cleaned data and future test window
df_hist <- read.csv("fact_air_quality_hourly.csv", stringsAsFactors = FALSE)
df_future <- read.csv("campus_air_quality_hourly_2026_test.csv", stringsAsFactors = FALSE)

# Filter for the target location (e.g., Main Gate)
target_loc <- "Main Gate"
cat(sprintf("Target Location: %s\n", target_loc))

hist_data <- df_hist %>% 
  filter(Location == target_loc) %>%
  arrange(Timestamp)

# 2. Extract training window (Trailing 14 days = 336 hours)
recent_hist <- tail(hist_data, 14 * 24)
ts_train <- ts(recent_hist$PM2.5, frequency = 24)

# Training Exogenous Matrix (Vehicle Traffic & Wind Speed)
xreg_train <- as.matrix(recent_hist[, c("Vehicle_Count", "Wind_Speed")])

cat(sprintf("Training SARIMAX on trailing 14 days (%d hours of recent history)...\n", nrow(recent_hist)))

# 3. Fit the Champion SARIMAX Model
fit_model <- auto.arima(
  ts_train,
  xreg = xreg_train,
  seasonal = TRUE,
  stepwise = TRUE,
  approximation = TRUE,
  max.p = 2, max.q = 2, max.P = 1, max.Q = 1
)

cat(sprintf("Model Specification: %s\n\n", as.character(fit_model)))

# 4. Prepare Tomorrow's 24 Hours of External Inputs
# (In production, from Weather API & Campus Traffic Schedule)
tomorrow_unseen <- df_future %>%
  filter(Location == target_loc) %>%
  arrange(Timestamp) %>%
  head(24)

xreg_tomorrow <- as.matrix(tomorrow_unseen[, c("Vehicle_Count", "Wind_Speed..m.s.")])

# 5. Generate 24-Hour Ahead Forecast
cat("Generating 24-Hour Predictive Horizon for Tomorrow...\n")
fc_24h <- forecast(fit_model, xreg = xreg_tomorrow, h = 24)

# 6. Map to Official AQI Categories & Health Advisories
get_aqi_info <- function(pm) {
  if (pm <= 30) {
    return(c("Good", "🟢 Ideal for outdoor sports & open windows"))
  } else if (pm <= 60) {
    return(c("Satisfactory", "🟡 Air quality is acceptable for campus population"))
  } else if (pm <= 90) {
    return(c("Moderate", "🟠 Sensitive students: limit prolonged exertion"))
  } else if (pm <= 120) {
    return(c("Poor", "🔴 Wear N95 near traffic gates; deploy mist cannons"))
  } else if (pm <= 250) {
    return(c("Very Poor", "🟣 Restrict outdoor physical activities"))
  } else {
    return(c("Severe", "⚫ Emergency: move all classes & training indoors"))
  }
}

aqi_categories <- character(24)
advisories <- character(24)

for (i in 1:24) {
  pred_val <- fc_24h$mean[i]
  info <- get_aqi_info(pred_val)
  aqi_categories[i] <- info[1]
  advisories[i] <- info[2]
}

# 7. Compile Final Output Schedule
tomorrow_schedule <- data.frame(
  Hour = sprintf("%02d:00", 0:23),
  Predicted_PM2.5 = round(as.numeric(fc_24h$mean), 1),
  Lower_95_CI = round(as.numeric(fc_24h$lower[, 2]), 1),
  Upper_95_CI = round(as.numeric(fc_24h$upper[, 2]), 1),
  Expected_Vehicles = tomorrow_unseen$Vehicle_Count,
  Expected_Wind_m_s = tomorrow_unseen$Wind_Speed..m.s.,
  AQI_Category = aqi_categories,
  Health_Advisory = advisories
)

# Print Executive Summary Table
cat("\n======================= TOMORROW'S 24-HOUR FORECAST =======================\n")
print(head(tomorrow_schedule, 12), row.names = FALSE)
cat("... (Hours 12:00 to 23:00 also compiled) ...\n\n")

# Save to CSV for dashboard or Power BI consumption
write.csv(tomorrow_schedule, "tomorrow_24h_forecast.csv", row.names = FALSE)
cat("Full 24-hour forecast saved to: tomorrow_24h_forecast.csv\n")

# Identify Peak Risk Hour
peak_idx <- which.max(tomorrow_schedule$Predicted_PM2.5)
peak_hour <- tomorrow_schedule$Hour[peak_idx]
peak_val <- tomorrow_schedule$Predicted_PM2.5[peak_idx]
peak_cat <- tomorrow_schedule$AQI_Category[peak_idx]

cat(sprintf("\n🚨 PEAK RISK ALERT: Tomorrow at %s, PM2.5 will peak at %.1f ug/m3 (%s)\n", peak_hour, peak_val, peak_cat))
cat("====================================================================\n")
