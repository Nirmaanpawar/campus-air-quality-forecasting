# Campus Air Quality Monitoring, Analysis & Forecasting 2026

An end-to-end environmental intelligence and predictive forecasting platform analyzing multi-pollutant concentrations ($\text{PM}_{2.5}$, $\text{CO}_2$, $\text{NO}_x$) alongside vehicular traffic, human footfall, and meteorological variables across campus micro-environments.

> 📖 **Comprehensive Documentation**: Complete beginner-friendly documentation, architecture diagrams, data cleaning guides, and technical interview questions are available in the **[`docs/`](docs/README.md)** directory.

---

## 📁 Project Structure & Deliverables

| File | Type | Description |
| :--- | :--- | :--- |
| **[`generate_synthetic_air_quality.py`](generate_synthetic_air_quality.py)** | Python Script | Physics-guided simulation engine generating realistic diurnal curves, events, and atmospheric dispersion. |
| **[`run_analysis_and_forecast.R`](run_analysis_and_forecast.R)** | R Script | Complete R pipeline for outlier cleaning, `na.approx` interpolation, ADF testing, ARIMA/SARIMA/SARIMAX modeling. |
| **[`campus_air_quality_hourly_2025.csv`](campus_air_quality_hourly_2025.csv)** | Raw Dataset | 70,080 hourly records covering the full year 2025 across all 8 campus locations. |
| **[`campus_air_quality_hourly_2026_test.csv`](campus_air_quality_hourly_2026_test.csv)** | Evaluation Dataset | 17,280 holdout test records for 2026 out-of-sample forecast validation. |
| **[`fact_air_quality_hourly.csv`](fact_air_quality_hourly.csv)** | Star Schema Fact | Cleaned environmental measurements with 24-hour rolling averages and AQI classification. |
| **[`dim_location.csv`](dim_location.csv)** | Star Schema Dimension| Geographic coordinates (lat/long), environment type (indoor/outdoor), and regulatory thresholds. |
| **[`dim_calendar.csv`](dim_calendar.csv)** | Star Schema Dimension| Date, month, day-of-week, hour, and weekend flags for Power BI slicing. |
| **[`fact_forecast_24h.csv`](fact_forecast_24h.csv)** | Forecast Output | 24-hour horizon comparing Actual $\text{PM}_{2.5}$ vs. SARIMA vs. SARIMAX with 95% confidence intervals. |
| **[`model_performance_metrics.csv`](model_performance_metrics.csv)** | Model Metrics | Accuracy benchmark table (RMSE, MAE, MAPE). |
| **[`POWER_BI_DASHBOARD_GUIDE.md`](POWER_BI_DASHBOARD_GUIDE.md)** | Documentation | Complete step-by-step Power BI guide including star-schema relationships and DAX measures. |
| **[`dashboard.html`](dashboard.html)** | Interactive App | Standalone web dashboard with interactive Leaflet campus map, Chart.js 24h forecast curve, and live alerts. |

---

## 📊 Model Benchmark Results (2026 Test Set)

Evaluated on the first 24-hour holdout period of 2026:

| Model Architecture | Specification | RMSE ($\mu\text{g/m}^3$) | MAE ($\mu\text{g/m}^3$) | MAPE (%) |
| :--- | :--- | :---: | :---: | :---: |
| **Standard ARIMA** | $\text{ARIMA}(2,0,0)$ with non-zero mean | 13.32 | 10.89 | 13.76% |
| **Seasonal SARIMA** | $\text{ARIMA}(1,0,2)(1,1,0)_{[24]}$ | 7.12 | 6.22 | 7.42% |
| **SARIMAX (Exogenous)** | $\text{Reg} + \text{ARIMA}(1,0,2)(1,1,0)_{[24]}$ | **6.05** | **5.12** | **6.15%** |

> **Key Takeaway**: Incorporating the 24-hour diurnal seasonal component reduced prediction error by **46.5%**, while adding exogenous traffic and wind covariates (SARIMAX) lowered the error by an additional **15%**, achieving a top MAPE of **6.15%**.

---

## 🚀 How to Run

### 1. Re-generate Synthetic Data
```bash
python3 generate_synthetic_air_quality.py
```

### 2. Execute Full R Analytics & Forecasting Pipeline
```bash
Rscript run_analysis_and_forecast.R
```

### 3. Launch Interactive Web Dashboard
Open `dashboard.html` in your web browser (or serve it locally):
```bash
python3 -m http.server 8080
# Visit http://localhost:8080/dashboard.html
```

### 4. Build Power BI Reports
Follow the instructions and DAX formulas inside [`POWER_BI_DASHBOARD_GUIDE.md`](POWER_BI_DASHBOARD_GUIDE.md).
