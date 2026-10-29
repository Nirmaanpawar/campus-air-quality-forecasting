# System Architecture & Component Design

This document details the modular architecture, component responsibilities, end-to-end execution workflow, and file inventory of the **Campus Air Quality Monitoring, Analysis, and Forecasting** platform.

---

## 🏛️ System Architecture Overview

The system is organized into three distinct tiers:
1. **Simulation & Data Generation Tier (Python)**: A dependency-free physics engine that simulates atmospheric chemistry, diurnal meteorological cycles, student/vehicular movement patterns, and sensor hardware degradation.
2. **Statistical Analytics & Modeling Tier (R)**: An end-to-end analytics pipeline that performs anomaly filtering, linear interpolation, stationarity hypothesis testing (ADF), model fitting (ARIMA, SARIMA, SARIMAX), out-of-sample holdout evaluation, and dimensional export.
3. **Consumption & Decision Support Tier (Power BI & HTML5/JS)**: A dual visualization interface comprising an enterprise dimensional Star Schema for Microsoft Power BI and a zero-dependency web application (`dashboard.html`) utilizing Leaflet.js and Chart.js.

### High-Level System Architecture Diagram

```mermaid
flowchart TD
    subgraph Tier1 ["Tier 1: Simulation & Data Generation (Python 3)"]
        GenScript["generate_synthetic_air_quality.py"]
        Physics["Physics Engine: Boundary Layer Inversion & Hygroscopic Growth"]
        Activity["Activity Curves: Rush Hour Traffic & Canteen Peaks"]
        Noise["AR(1) State Continuity & Glitch Injection"]
        
        GenScript --> Physics & Activity
        Physics & Activity --> Noise
        Noise --> Raw2025[("campus_air_quality_hourly_2025.csv<br/>(Full Year Training / EDA)")]
        Noise --> Raw2026[("campus_air_quality_hourly_2026_test.csv<br/>(Q1 2026 Holdout Evaluation)")]
    end

    subgraph Tier2 ["Tier 2: Statistical Analytics & Modeling (R 4.x)"]
        MainPipeline["run_analysis_and_forecast.R"]
        PredictScript["predict_tomorrow_24h.R"]
        
        Raw2025 & Raw2026 --> MainPipeline
        
        Clean["Data Cleaning: Flag >500 as NA &<br/>Linear Interpolation (zoo::na.approx)"]
        Stationarity["Stationarity Diagnostics:<br/>Augmented Dickey-Fuller Test"]
        Models["Model Estimation (forecast::auto.arima):<br/>1. ARIMA(2,0,0)<br/>2. SARIMA(1,0,2)(1,1,0)[24]<br/>3. SARIMAX (Traffic + Wind)"]
        Eval["Holdout Evaluation:<br/>RMSE, MAE, MAPE on Jan 1, 2026"]
        
        MainPipeline --> Clean --> Stationarity --> Models --> Eval
        
        Clean --> StarSchemaExport["Star Schema Export Engine"]
        Models --> PredictScript
    end

    subgraph Tier3 ["Tier 3: Relational Storage & Consumption"]
        StarSchemaExport --> FactTable[("fact_air_quality_hourly.csv")]
        StarSchemaExport --> DimLoc[("dim_location.csv")]
        StarSchemaExport --> DimCal[("dim_calendar.csv")]
        Eval --> FactForecast[("fact_forecast_24h.csv")]
        Eval --> MetricsCSV[("model_performance_metrics.csv")]
        PredictScript --> TomorrowCSV[("tomorrow_24h_forecast.csv")]
        
        FactTable & DimLoc & DimCal & FactForecast & MetricsCSV --> PowerBI["Microsoft Power BI Desktop<br/>(Star Schema Model & DAX)"]
        FactForecast & DimLoc & MetricsCSV --> WebDash["Interactive Web Dashboard<br/>(dashboard.html via Chart.js + Leaflet)"]
    end
```

---

## 🔄 End-to-End Data Flow

The following data-flow diagram tracks the exact transformation stages of environmental records from initial generation to decision support:

```mermaid
flowchart LR
    A["Raw Synthetic Generation<br/>(Hour, Season, Micro-climate)"] --> B["Data Cleaning Filter<br/>(Outliers > 500 ug/m3 -> NA)"]
    B --> C["Time-Series Linear Interpolation<br/>(zoo::na.approx rule=2 by Location)"]
    C --> D["24h Trailing Moving Average<br/>(zoo::rollapply width=24)"]
    
    D --> E["Exploratory Spatial &<br/>Correlation Analytics"]
    D --> F["14-Day Trailing Window Slice<br/>(336 Hourly Observations)"]
    
    F --> G["SARIMAX Estimation &<br/>Exogenous Regression"]
    G --> H["24h Predictive Horizon Generation<br/>(Point Forecasts + 95% Confidence Bounds)"]
    
    H --> I["Star Schema Relational Export"]
    I --> J["Power BI Dashboards & Web Alerts"]
```

---

## 🔬 Model Training & Evaluation Workflow

The evaluation workflow adheres strictly to temporal ordering, ensuring that future data never contaminates model parameter estimation:

```mermaid
sequenceDiagram
    autonumber
    participant D as Data Storage
    participant P as Pipeline (R)
    participant M as Models (auto.arima)
    participant E as Evaluator (calc_metrics)
    participant S as Star Schema / UI

    D->>P: Load 2025 History (70,080 rows) & 2026 Test (17,280 rows)
    P->>P: Group by Location & interpolate missing values
    P->>P: Filter Location == 'Main Gate'
    P->>P: Slice Trailing 14 Days of 2025 (336 hours) as Training Set
    P->>M: Fit Model 1: Non-seasonal ARIMA(2,0,0)
    P->>M: Fit Model 2: Seasonal SARIMA(1,0,2)(1,1,0)[24]
    P->>M: Fit Model 3: Seasonal SARIMAX with Traffic & Wind Covariates
    M-->>P: Model objects with estimated coefficients
    D->>P: Slice First 24 Hours of 2026 (Jan 1, 00:00 to 23:00) as Holdout
    P->>M: forecast(h = 24, xreg = test_covariates)
    M-->>P: Forecast vectors (mean, lower 95%, upper 95%)
    P->>E: Compare Actual vs. Predicted (RMSE, MAE, MAPE)
    E-->>P: Performance Summary Table
    P->>S: Write fact_forecast_24h.csv & model_performance_metrics.csv
```

---

## 📂 Verified File Inventory

Every significant file in the workspace serves a specific, verified operational purpose:

### 1. Source Scripts & Applications
* **[`generate_synthetic_air_quality.py`](../generate_synthetic_air_quality.py)**:
  * **Role**: Primary data simulation engine.
  * **Language**: Python 3 (built exclusively with standard library modules: `csv`, `math`, `random`, `datetime`).
  * **Output**: Generates `campus_air_quality_hourly_2025.csv` and `campus_air_quality_hourly_2026_test.csv`.
* **[`run_analysis_and_forecast.R`](../run_analysis_and_forecast.R)**:
  * **Role**: Main analytics and time-series modeling engine.
  * **Language**: R 4.x (utilizing `forecast`, `zoo`, `dplyr`, `tseries`, `ggplot2`).
  * **Output**: Cleans data, runs ADF test, trains ARIMA/SARIMA/SARIMAX, evaluates 24h performance, and exports all Star Schema tables.
* **[`predict_tomorrow_24h.R`](../predict_tomorrow_24h.R)**:
  * **Role**: Dedicated operational forecasting script for day-ahead campus management.
  * **Language**: R 4.x.
  * **Output**: Fits the champion SARIMAX model, predicts the next 24 hours, maps outputs to official AQI categories and health advisories, and flags the peak pollution hour in `tomorrow_24h_forecast.csv`.
* **[`dashboard.html`](../dashboard.html)**:
  * **Role**: Interactive web dashboard for cross-platform visual exploration.
  * **Language**: HTML5, Vanilla JavaScript, Tailwind CSS (CDN), Chart.js (CDN), Leaflet.js (CDN).
  * **Output**: Renders the campus map, 24-hour forecast curve with shaded 95% confidence intervals, and activity correlation scatter plots.

### 2. Configuration & Documentation Files
* **[`POWER_BI_DASHBOARD_GUIDE.md`](../POWER_BI_DASHBOARD_GUIDE.md)**: Comprehensive implementation guide detailing Star Schema relationships, DAX measure code, and report page configurations for Microsoft Power BI Desktop.
* **[`decisions.md`](../decisions.md)**: Architectural and technical decisions log detailing rationale, alternatives considered, trade-offs, and consequences for each major engineering choice.
* **[`flow.md`](../flow.md)**: Low-level execution trace and module interaction reference.
* **[`README.md`](../README.md)**: High-level repository landing page and project overview.
* **[`.gitignore`](../.gitignore)**: Git exclusion rules for operating system artifacts and temporary directories.

### 3. Generated Datasets & Relational Tables
* **`campus_air_quality_hourly_2025.csv`**: Raw simulated dataset for full year 2025 (70,080 rows; 8,760 hours $\times$ 8 locations). Contains synthetic sensor glitches for testing data cleaning.
* **`campus_air_quality_hourly_2026_test.csv`**: Raw simulated holdout dataset for Q1 2026 (17,280 rows; 2,160 hours $\times$ 8 locations). Used for out-of-sample model evaluation.
* **`fact_air_quality_hourly.csv`**: Cleaned, imputed fact table containing environmental measurements, calculated 24-hour rolling averages, and AQI categories for 2025 (70,080 rows).
* **`dim_location.csv`**: Location dimension table containing GPS coordinates (latitude/longitude), facility classifications (indoor vs. outdoor), and regulatory thresholds for all 8 campus stations.
* **`dim_calendar.csv`**: Temporal dimension table containing hourly timestamps, date components, day of the week, month names, and weekend flags spanning 2025-01-01 through 2026-03-31 (10,944 rows).
* **`fact_forecast_24h.csv`**: 24-hour forecast evaluation table comparing actual holdout measurements against SARIMA and SARIMAX predictions, complete with 95% prediction intervals.
* **`model_performance_metrics.csv`**: Benchmark table recording the exact RMSE, MAE, and MAPE metrics for ARIMA, SARIMA, and SARIMAX.
* **`tomorrow_24h_forecast.csv`**: Operational forecast schedule generated by `predict_tomorrow_24h.R`, detailing hourly predictions, confidence bounds, expected vehicles, wind speed, AQI category, and safety actions.

---

## 🚀 Workflow Entry Points

The project supports three primary operational workflows initiated via terminal commands:

| Workflow | Entry Command | Primary Script | Artifacts Produced |
| :--- | :--- | :--- | :--- |
| **1. Data Simulation** | `python3 generate_synthetic_air_quality.py` | `generate_synthetic_air_quality.py` | `campus_air_quality_hourly_2025.csv`<br>`campus_air_quality_hourly_2026_test.csv` |
| **2. Analytics & Modeling Pipeline** | `Rscript run_analysis_and_forecast.R` | `run_analysis_and_forecast.R` | `fact_air_quality_hourly.csv`<br>`dim_location.csv`<br>`dim_calendar.csv`<br>`fact_forecast_24h.csv`<br>`model_performance_metrics.csv` |
| **3. Operational 24h Prediction** | `Rscript predict_tomorrow_24h.R` | `predict_tomorrow_24h.R` | `tomorrow_24h_forecast.csv` |
| **4. Web Dashboard Visualizer** | `python3 -m http.server 8080` | `dashboard.html` | Browser rendering at `http://localhost:8080/dashboard.html` |
