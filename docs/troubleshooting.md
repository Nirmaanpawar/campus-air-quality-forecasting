# Troubleshooting & Common Issues Guide

This document catalogs common errors, unexpected behaviors, and practical diagnostic remedies grounded directly in the execution of the **Campus Air Quality Monitoring, Analysis, and Forecasting** pipeline.

---

## 🚨 Quick Diagnostic Matrix

| Symptom / Error Message | Likely Root Cause | Immediate Remediation |
| :--- | :--- | :--- |
| `auto.arima()` hangs indefinitely or causes high CPU usage | Exact CSS-ML parameter search on seasonal period $s = 24$. | Set `approximation = TRUE` and restrict order bounds (`max.p = 2`, `max.q = 2`, `max.P = 1`, `max.Q = 1`). |
| `Error in recent_train[, c("Vehicle_Count", "Wind_Speed")] : subscript out of bounds` | R's `read.csv()` sanitized `Wind_Speed (m/s)` to `Wind_Speed..m.s.`. | Inspect column names via `names(df)` and reference `Wind_Speed..m.s.`. |
| `Warning: xreg contains different column names from the xreg used in training` | Training matrix used `Wind_Speed`; test matrix used `Wind_Speed..m.s.`. | Standardize column names before converting to `as.matrix()`. |
| `ModuleNotFoundError: No module named 'pandas'` | Attempting to import third-party packages in Python script. | The data generator requires **zero** external packages; run with standard Python 3. |
| Time-series forecast produces a flat horizontal line after 2–3 hours | Using non-seasonal ARIMA for diurnal data with a 24-hour cycle. | Switch to Seasonal SARIMA or SARIMAX with `frequency = 24`. |
| Cannot install Power BI Desktop on macOS or Linux | Power BI Desktop is exclusively compiled for Windows. | Use [`dashboard.html`](../dashboard.html) for local browser visualization or use the Power BI web service. |
| Power BI reports duplicate key or relationship cardinality errors | Dim tables contain duplicate timestamps or location names. | Confirm `dim_calendar` has unique timestamps and `dim_location` has exactly 8 unique location rows. |

---

## 🛠️ In-Depth Troubleshooting Scenarios

### 1. `auto.arima()` Hangs or Freezes During Model Search
* **Symptom**: Executing `run_analysis_and_forecast.R` stalls at step `[5/6] Training & Benchmarking Models...` for several minutes with fans running at full capacity.
* **Root Cause**: When modeling hourly series with daily seasonality ($s = 24$), setting `approximation = FALSE` or allowing unconstrained high-order searches forces R to invert large $24 \times 24$ covariance matrices for every candidate $(p,d,q)(P,D,Q)$ combination.
* **Resolution**: Ensure your `auto.arima` call includes `approximation = TRUE` and bounded orders:
  ```r
  # Fast, robust approximation:
  fit_sarima <- auto.arima(
    ts_recent,
    seasonal = TRUE,
    stepwise = TRUE,
    approximation = TRUE,
    max.p = 2, max.q = 2, max.P = 1, max.Q = 1
  )
  ```
  This reduces execution time to less than 2 seconds without meaningfully degrading model selection.

---

### 2. Column Name Sanitization & Subscript Out of Bounds in R
* **Symptom**:
  ```
  Error in `[.data.frame`(recent_train, , c("Vehicle_Count", "Wind_Speed")) : 
    subscript out of bounds
  ```
* **Root Cause**: In [`generate_synthetic_air_quality.py`](../generate_synthetic_air_quality.py), the wind column is written to CSV with unit annotations: `Wind_Speed (m/s)`. When R's `read.csv()` imports this file with default settings (`check.names = TRUE`), it replaces parentheses and spaces with periods, creating the variable `Wind_Speed..m.s.`.
* **Resolution**:
  1. Inspect the loaded data frame using `names(raw_data_2025)`.
  2. In your subsetting code, use the sanitized name:
     ```r
     xreg_train <- as.matrix(recent_train[, c("Vehicle_Count", "Wind_Speed..m.s.")])
     ```
  3. Alternatively, rename the column immediately after loading:
     ```r
     colnames(raw_data_2025)[colnames(raw_data_2025) == "Wind_Speed..m.s."] <- "Wind_Speed"
     ```

---

### 3. Warning: Regressor Column Names Differ in `predict_tomorrow_24h.R`
* **Symptom**:
  ```
  Warning message:
  In forecast.Arima(fit_model, xreg = xreg_tomorrow, h = 24) :
    xreg contains different column names from the xreg used in training. Please check that the regressors are in the same order.
  ```
* **Root Cause**: In `predict_tomorrow_24h.R`, the training matrix is built from `fact_air_quality_hourly.csv` (which exported the column as `Wind_Speed`). The prediction matrix is built from `campus_air_quality_hourly_2026_test.csv` (which retains `Wind_Speed..m.s.`).
* **Resolution**: While R successfully evaluates predictions based on column index position (Column 1 = `Vehicle_Count`, Column 2 = Wind Speed), you can eliminate the warning by assigning matching column names:
  ```r
  colnames(xreg_tomorrow) <- colnames(xreg_train)
  ```

---

### 4. Non-Stationarity & ADF Test Interpretation
* **Symptom**: The Augmented Dickey-Fuller test outputs a high $p$-value ($p = 0.2486$). An engineer might wonder if the pipeline is broken because the series is "not stationary."
* **Root Cause**: Ambient air pollution naturally displays non-stationary daily solar cycles and seasonal weather trends. A $p$-value above $0.05$ simply confirms that the series has a unit root and requires differencing.
* **Resolution**: This is expected behavior. The pipeline handles this automatically:
  * In non-seasonal ARIMA, `auto.arima` evaluates $d \in \{0, 1, 2\}$.
  * In seasonal SARIMA, seasonal differencing $D = 1$ is applied ($y_t - y_{t-24}$), which eliminates the diurnal baseline and produces a stationary seasonal difference series.

---

### 5. Flat Prediction Line from Standard ARIMA
* **Symptom**: When plotting a 24-hour horizon generated by Model 1 (`fit_arima`), the forecast drops or rises for 2 hours and then flattens into an unchanging horizontal line for the remaining 22 hours.
* **Root Cause**: Non-seasonal $\text{ARIMA}(2,0,0)$ models only capture immediate short-term memory (lags $t-1$ and $t-2$). As the forecast horizon extends beyond the lag order without seasonal memory, the autoregressive terms decay geometrically to zero, leaving only the stationary mean.
* **Resolution**: This behavior is standard statistical theory, not a bug. It demonstrates why univariate non-seasonal ARIMA is unsuitable for diurnal day-ahead forecasting and why Seasonal $\text{SARIMA}$ (Model 2) and $\text{SARIMAX}$ (Model 3) are mandatory.

---

### 6. Power BI Desktop Unavailable on macOS / Linux
* **Symptom**: A student or team member running macOS or Linux cannot double-click a `.pbix` file or install Power BI Desktop.
* **Resolution**:
  1. Open [`dashboard.html`](../dashboard.html) in any browser (Chrome/Safari) using:
     ```bash
     python3 -m http.server 8080
     ```
     This renders the interactive Leaflet map, Chart.js 24-hour forecast curve, and scatter plots natively on macOS/Linux.
  2. For cloud Power BI access, upload the exported CSV files to OneDrive/SharePoint and build the report via the **Power BI Service** web editor (`https://app.powerbi.com`).

---

### 7. Missing Value Imputation (`zoo::na.approx`) Edge Cases
* **Symptom**: Running `na.approx()` on a dataset with leading or trailing `NA` values returns an error or fails to remove all `NA`s.
* **Root Cause**: Standard linear interpolation requires boundary values before and after a missing interval. If a sensor fails on the very first or very last record of a time series, there is no outer boundary point.
* **Resolution**: Always specify `rule = 2` in `zoo::na.approx()`:
  ```r
  PM2.5_clean = na.approx(PM2.5..ug.m3., rule = 2)
  ```
  `rule = 2` instructs the algorithm to extrapolate the closest boundary value for edge dropouts.
