# Testing, Reproducibility & Verification Guide

This document specifies the exact software environment, step-by-step reproduction commands, verification outputs, reproducibility constraints, and observed code nuances in the **Campus Air Quality Monitoring, Analysis, and Forecasting** repository.

---

## 💻 Verified Execution Environment

The codebase was tested and verified under the following runtime specifications:

* **Operating System**: macOS (Darwin 24.x / Apple Silicon ARM64 & Intel compatible; POSIX Linux and Windows supported).
* **Python Runtime**: **Python 3.13.1**
  * *Required Packages*: **None** (Built strictly using Python Standard Library: `csv`, `math`, `random`, `datetime`). Zero `pip` dependencies are required.
* **R Runtime**: **R version 4.x** (e.g., R 4.4.x / 4.3.x)
  * *Required R Packages*:
    * `forecast` (Time-series modeling & `auto.arima`)
    * `zoo` (Time-series rollapply & `na.approx` interpolation)
    * `dplyr` (Data manipulation & aggregations)
    * `tseries` (Augmented Dickey-Fuller stationarity testing)
    * `ggplot2` (Statistical plotting & visual graphics)
* **Web Environment**: Any modern evergreen browser (Chrome, Edge, Safari, Firefox) with WebGL and JavaScript enabled.

---

## 📦 Environment Setup & Installation

### 1. Python Environment Setup
Because [`generate_synthetic_air_quality.py`](../generate_synthetic_air_quality.py) relies exclusively on the Python standard library, no virtual environment or package installation is required:
```bash
# Verify Python 3 is installed
python3 --version
```

### 2. R Package Installation
Install the necessary CRAN libraries from an interactive R session or terminal command:
```bash
Rscript -e 'install.packages(c("forecast", "zoo", "dplyr", "tseries", "ggplot2"), repos="https://cloud.r-project.org")'
```

---

## 🛠️ Step-by-Step Reproduction Commands

Execute the pipeline in sequence from the root of the repository:

### Step 1: Synthesize Environmental & Activity Datasets
```bash
python3 generate_synthetic_air_quality.py
```
* **Expected Terminal Output**:
  ```
  Generated 70080 records in campus_air_quality_hourly_2025.csv
  Generated 17280 records in campus_air_quality_hourly_2026_test.csv
  ```
* **Artifacts Created**:
  * `campus_air_quality_hourly_2025.csv` (70,080 rows; $\approx 6.5\ \text{MB}$)
  * `campus_air_quality_hourly_2026_test.csv` (17,280 rows; $\approx 1.6\ \text{MB}$)

### Step 2: Run End-to-End Analytics, Modeling & Star-Schema Export
```bash
Rscript run_analysis_and_forecast.R
```
* **Expected Terminal Output**:
  ```
  ====================================================================
  Starting Campus Air Quality Analytics & Forecasting Pipeline
  ====================================================================

  [1/6] Loading raw time-series datasets...
     - 2025 Training Records: 70080
     - 2026 Evaluation Records: 17280

  [2/6] Executing Data Cleaning & Time-Series Imputation...
     - Outliers flagged (>500 ug/m3): 140
     - Missing values detected: PM2.5=271, CO2=201, NOx=0
     - Outliers flagged (>500 ug/m3): 0
     - Missing values detected: PM2.5=0, CO2=0, NOx=0

  [3/6] Performing Exploratory Data Analysis & Spatial Analytics...
  ...
  Key Physical Correlations:
     - Vehicle Count <-> NOx Correlation: 0.633 (Strong Vehicle Combustion Link)
     - Vehicle Count <-> PM2.5 Correlation: 0.443
     - Library Footfall <-> CO2 Correlation: 0.695 (Strong Respiration Accumulation)

  [4/6] Conducting Time-Series Diagnostics (Main Gate Focus)...
     - Augmented Dickey-Fuller Test Statistic: -2.778 (p-value: 0.2486)
       -> Differencing is required.

  [5/6] Training & Benchmarking Models...
     - Fitting Model 1: Standard ARIMA...
     - Fitting Model 2: Seasonal ARIMA (SARIMA s=24)...
     - Fitting Model 3: SARIMAX (with Exogenous Covariates)...

  --- Model Forecast Performance Comparison (24h Ahead Horizon) ---
                                          Model                               Specification  RMSE   MAE  MAPE
  1                        ARIMA (Non-seasonal)             ARIMA(2,0,0) with non-zero mean 13.32 10.89 13.76
  2                       SARIMA (Seasonal 24h)                       ARIMA(1,0,2)(1,1,0)[24]  7.12  6.22  7.42
  3 SARIMAX (Seasonal + Exogenous Traffic/Wind) Regression with ARIMA(1,0,2)(1,1,0)[24] errors  6.05  5.12  6.15

  [6/6] Generating Power BI Data Model Tables...
     -> Exported 'fact_air_quality_hourly.csv' (Clean Fact Table)
     -> Exported 'dim_location.csv' (Dimension Table with GPS coordinates)
     -> Exported 'dim_calendar.csv' (Time Dimension)
     -> Exported 'fact_forecast_24h.csv' (24-Hour Forecast Horizon)
     -> Exported 'model_performance_metrics.csv' (Model Comparison Metrics)

  ====================================================================
  Pipeline Completed Successfully! All deliverables generated.
  ====================================================================
  ```

### Step 3: Run the Day-Ahead Operational Forecast Script
```bash
Rscript predict_tomorrow_24h.R
```
* **Expected Terminal Output**:
  ```
  ====================================================================
        Campus Air Quality: 24-Hour Tomorrow Forecast Engine          
  ====================================================================

  Target Location: Main Gate
  Training SARIMAX on trailing 14 days (336 hours of recent history)...
  Model Specification: Regression with ARIMA(1,0,2)(1,1,0)[24] errors

  Generating 24-Hour Predictive Horizon for Tomorrow...

  ======================= TOMORROW'S 24-HOUR FORECAST =======================
   Hour Predicted_PM2.5 Lower_95_CI Upper_95_CI Expected_Vehicles Expected_Wind_m_s AQI_Category                                Health_Advisory
  00:00           102.7       100.1       105.3                16               1.4         Poor 🔴 Wear N95 near traffic gates; deploy mist cannons
  01:00           103.4        99.4       107.4                16               1.5         Poor 🔴 Wear N95 near traffic gates; deploy mist cannons
  ...
  🚨 PEAK RISK ALERT: Tomorrow at 04:00, PM2.5 will peak at 106.5 ug/m3 (Poor)
  ====================================================================
  ```
* **Artifact Created**: `tomorrow_24h_forecast.csv`

### Step 4: Launch Web Dashboard
```bash
python3 -m http.server 8080
```
Open `http://localhost:8080/dashboard.html` in your web browser.

---

## 🔒 Reproducibility Constraints & Determinism

1. **Python Random Seed**:
   * The synthetic generator explicitly sets `random.seed(42)` at line 14 of [`generate_synthetic_air_quality.py`](../generate_synthetic_air_quality.py#L14). Re-running the generator reproduces the exact identical sequence of floating-point values and simulated missingness patterns.
2. **R Model Estimation Determinism**:
   * The Hyndman-Khandakar stepwise algorithm in `forecast::auto.arima()` is deterministic for a given dataset and bounded search space. It evaluates candidate models via analytical AICc formulas without stochastic initialization.
3. **No External Network Dependencies**:
   * The modeling and data synthesis steps do not call external REST APIs or cloud endpoints during pipeline execution.

---

## 🧪 Test Coverage & Status

* **Current Verification Strategy**: The project currently relies on **end-to-end integration and out-of-sample holdout validation**. The pipeline script executes all cleaning routines, fits 3 model variants, evaluates metric boundaries against known ground truth, and verifies row/column shapes.
* **Formal Unit Test Framework**: No unit test framework (such as `testthat` for R or `pytest` for Python) is currently configured in the workspace. In an enterprise production deployment, adding unit tests for individual cleaning functions and input boundary conditions is recommended.

---

## ⚠️ Potential Issues & Code Observations

During inspection and verified execution of the existing code, the following non-fatal issues and behaviors were identified:

### 1. Column Naming Warning in `predict_tomorrow_24h.R`
* **Observed Warning**:
  ```
  Warning message:
  In forecast.Arima(fit_model, xreg = xreg_tomorrow, h = 24) :
    xreg contains different column names from the xreg used in training. Please check that the regressors are in the same order.
  ```
* **Root Cause**: In [`predict_tomorrow_24h.R`](../predict_tomorrow_24h.R#L33-L56), `xreg_train` is extracted from `fact_air_quality_hourly.csv` where the column is named `Wind_Speed`. However, `xreg_tomorrow` is extracted from `campus_air_quality_hourly_2026_test.csv` where the column is named `Wind_Speed..m.s.` (sanitized from `Wind_Speed (m/s)`).
* **Impact**: R matches columns strictly by index position in the numeric matrix, so the prediction math executes correctly; however, the warning is emitted to standard error.
* **Recommended Harmonization**: Ensure column names in `df_future` are renamed to match `df_hist` prior to matrix conversion.

### 2. Character Sanitization in R's `read.csv()`
* **Behavior**: R's default CSV reader replaces special characters like parentheses, spaces, and slashes with periods. For example, `Wind_Speed (m/s)` becomes `Wind_Speed..m.s.`.
* **Impact**: Subsetting by `c("Vehicle_Count", "Wind_Speed")` directly on raw imported CSVs results in an `Error: subscript out of bounds`. The code in `run_analysis_and_forecast.R` correctly references `Wind_Speed..m.s.` to accommodate this.
