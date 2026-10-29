# Campus Air Quality Monitoring, Analysis & Forecasting — Documentation

Welcome to the comprehensive documentation for the **Campus Air Quality Monitoring, Analysis, and Forecasting** project. 

This project is an end-to-end environmental intelligence platform that combines physics-guided simulation, automated data cleaning, exploratory spatial analysis, statistical time-series forecasting (ARIMA, SARIMA, SARIMAX), and executive visual analytics (Power BI Star Schema & standalone HTML5/JavaScript dashboard).

---

## 📚 Documentation Index

| Document | Topic & Focus Area | Key Contents |
| :--- | :--- | :--- |
| **[`architecture.md`](architecture.md)** | System & Data Architecture | Component responsibilities, end-to-end data flow, execution sequence, Mermaid system diagrams, and complete file inventory. |
| **[`data-and-cleaning.md`](data-and-cleaning.md)** | Data Pipeline & Preprocessing | Data origin (synthetic vs. real), schema specifications, sensor artifact injection, linear interpolation (`zoo::na.approx`), rolling moving averages, and data leakage safeguards. |
| **[`models-and-evaluation.md`](models-and-evaluation.md)** | Time-Series Forecasting & Metrics | Stationarity diagnostics (ADF test), mathematical formulations of ARIMA/SARIMA/SARIMAX, parameter selection rationale, empirical benchmark results, and multi-step limitations. |
| **[`dashboard-and-power-bi.md`](dashboard-and-power-bi.md)** | Business Intelligence & Web App | Power BI star-schema design, relationship cardinality, core DAX measure formulations, report page layouts, and the standalone zero-dependency web dashboard (`dashboard.html`). |
| **[`testing-and-reproducibility.md`](testing-and-reproducibility.md)** | Environment, Commands & Verification | Verified runtime environments (Python 3, R 4.x), exact CLI commands to reproduce all outputs, deterministic seeds, test status, and documented observations. |
| **[`troubleshooting.md`](troubleshooting.md)** | Common Issues & Practical Checks | Concrete failure modes grounded in actual project execution (e.g., `auto.arima` CPU hanging, R column naming sanitization, missing packages), diagnostic steps, and fixes. |
| **[`glossary-and-interview-guide.md`](glossary-and-interview-guide.md)** | Terms & Technical Interview Prep | Plain-language definitions for air quality and time-series concepts, accompanied by rigorous interview Q&A grounded in the project codebase. |

---

## 🎯 Project Summary & Core Objectives

### The Problem
Educational institutions and corporate campuses experience significant spatial and temporal variations in air quality. Traffic gates endure heavy particulate ($\text{PM}_{2.5}$) and nitrogen oxide ($\text{NO}_x$) combustion surges during morning and evening rush hours. Conversely, enclosed study halls (libraries) and cafeterias accumulate metabolic carbon dioxide ($\text{CO}_2$) due to high student occupancy and restricted ventilation. 

Without targeted micro-climate monitoring and forward-looking forecasts:
1. Campus administrators cannot take proactive measures (such as rerouting traffic, activating dust-suppression mist cannons, or ramping HVAC fresh air intake).
2. Students with respiratory sensitivities (e.g., asthma) lack actionable early warnings regarding peak pollution periods.

### What the Project Does
* **Simulates 8 Campus Micro-Climates**: Generates hourly multi-pollutant telemetry ($\text{PM}_{2.5}$, $\text{CO}_2$, $\text{NO}_x$), meteorology (temperature, humidity, wind), and activity metrics (traffic count, human footfall) across outdoor gates, parking facilities, residential hostels, recreational grounds, and indoor study/dining halls.
* **Performs Automated Sensor Cleaning**: Detects hardware saturation errors ($> 500\ \mu\text{g/m}^3$), handles missing transmission packets, and imputes clean temporal trajectories via localized linear interpolation.
* **Validates Statistical Stationarity**: Evaluates unit roots using the Augmented Dickey-Fuller (ADF) test to mathematically determine the required integration order ($d$).
* **Benchmarks 3 Time-Series Architectures**:
  1. *Baseline Univariate $\text{ARIMA}(2,0,0)$*: Captures short-term autoregressive momentum.
  2. *Seasonal $\text{SARIMA}(1,0,2)(1,1,0)_{[24]}$*: Models the recurring 24-hour diurnal atmospheric cycle.
  3. *Exogenous $\text{SARIMAX}$*: Fuses the 24-hour diurnal cycle with external physical drivers (`Vehicle_Count` and `Wind_Speed`).
* **Delivers Dual Visualization Layers**:
  * An enterprise **Microsoft Power BI** Star Schema with custom DAX measures for executive reporting.
  * A standalone, lightweight **Web Dashboard (`dashboard.html`)** built with Leaflet.js and Chart.js for cross-platform zero-dependency visual verification.

### What the Project Does Not Do
* It does **not** ingest live real-time streams from physical IoT hardware out-of-the-box (the current pipeline runs on physics-guided synthetic data generated with fixed random seeds).
* It does **not** train deep learning sequence models (such as LSTM, GRU, or Temporal Fusion Transformers); it focuses on interpretable statistical models with exact confidence intervals.
* It does **not** forecast beyond a 24-hour day-ahead horizon, as meteorological uncertainty and cumulative autoregressive error degrade longer projections.

---

## ⚡ Quick-Start Reproduction Guide

To reproduce the complete pipeline from scratch, follow these four verified steps:

```bash
# 1. Clone or navigate to the repository
cd "/Users/nirmanpawar/Downloads/untitled folder"

# 2. Generate the synthetic time-series datasets (Full Year 2025 + Q1 2026 Holdout)
python3 generate_synthetic_air_quality.py

# 3. Execute the R cleaning, ADF stationarity test, model benchmarking, and star-schema export
Rscript run_analysis_and_forecast.R

# 4. (Optional) Run the day-ahead operational forecast script for tomorrow's schedule
Rscript predict_tomorrow_24h.R

# 5. Open the interactive web dashboard in your browser
python3 -m http.server 8080
# Visit http://localhost:8080/dashboard.html
```

For complete environment specifications, package installation steps, and verification logs, see [`testing-and-reproducibility.md`](testing-and-reproducibility.md).
