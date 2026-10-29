# Technical Glossary & Comprehensive Interview Guide

This document provides beginner-friendly definitions of core environmental and statistical concepts, followed by a rigorous technical interview preparation guide grounded directly in the codebase and architectural decisions of this project.

---

## 📖 Plain-Language Technical Glossary

### 1. Environmental & Air Quality Terminology
* **$\text{PM}_{2.5}$ (Fine Particulate Matter)**: Microscopic airborne particles with an aerodynamic diameter $\le 2.5\ \mu\text{m}$. Measured in micrograms per cubic meter ($\mu\text{g/m}^3$). Capable of penetrating deep into the lungs and bloodstream. Primary target variable of this forecasting system.
* **$\text{CO}_2$ (Carbon Dioxide)**: A trace gas measured in parts per million (ppm). Outdoors, global baseline levels sit around $415\text{–}420\ \text{ppm}$. In indoor spaces (libraries, classrooms), it accumulates due to human metabolic respiration, serving as a direct tracer of ventilation efficacy.
* **$\text{NO}_x$ (Nitrogen Oxides)**: A group of reactive gases ($\text{NO}$ and $\text{NO}_2$) measured in parts per billion (ppb). Formed during high-temperature fossil fuel combustion; serves as the primary chemical fingerprint for vehicular traffic near campus gates.
* **Diurnal Cycle**: A daily recurring pattern driven by the 24-hour cycle of sunlight, surface heating, human activity (commute rush hours), and atmospheric mixing.
* **Thermal Inversion (Planetary Boundary Layer)**: A meteorological condition where warm air caps cooler air near the ground at night. This traps vehicle emissions near the surface, causing $\text{PM}_{2.5}$ to peak in early morning hours before sunlight destabilizes the layer.
* **Hygroscopic Swelling**: Physical process where fine particulate matter absorbs ambient water vapor at high relative humidity ($\text{RH} > 75\%$), causing optical sensors to perceive particles as larger and more concentrated.

### 2. Time-Series Modeling Terminology
* **Stationarity**: A statistical property where the mean, variance, and autocorrelation of a time series do not change over calendar time. Autoregressive models require stationary data to generate valid, stable predictions.
* **Unit Root**: A stochastic trend in a time series that causes non-stationarity. If a series has a unit root, past shocks exert permanent effects rather than decaying to zero.
* **Augmented Dickey-Fuller (ADF) Test**: A hypothesis test used to detect unit roots. A $p$-value $< 0.05$ rejects the unit root hypothesis, proving stationarity. A $p$-value $\ge 0.05$ indicates differencing ($d \ge 1$) is necessary.
* **Differencing ($d$ and $D$)**: Subtracting past observations from current values to remove trends and seasonality. Non-seasonal differencing is $y_t - y_{t-1}$ ($d=1$). Seasonal differencing is $y_t - y_{t-24}$ ($D=1$).
* **Lag Operator ($B$)**: A backshift notation where $B y_t = y_{t-1}$ and $B^{24} y_t = y_{t-24}$.
* **Autoregression ($\text{AR}$)**: Modeling the current value $y_t$ as a linear combination of its own previous lags ($y_{t-1}, y_{t-2}$).
* **Moving Average ($\text{MA}$)**: Modeling the current value $y_t$ as a linear combination of past white-noise forecast error shocks ($\epsilon_{t-1}, \epsilon_{t-2}$).
* **$\text{SARIMA}(p,d,q)(P,D,Q)_{[s]}$**: Seasonal Autoregressive Integrated Moving Average. Incorporates both immediate lags ($p,d,q$) and seasonal periodic lags ($P,D,Q$) at recurring frequency $s = 24$.
* **$\text{SARIMAX}$**: A regression model where external explanatory drivers ($X$: `Vehicle_Count`, `Wind_Speed`) explain the structural level of the series, and a $\text{SARIMA}$ model captures the autocorrelated disturbance errors.
* **AICc (Akaike Information Criterion corrected)**: A metric used by `auto.arima()` to balance goodness-of-fit against model complexity, penalizing overfitting on finite samples. Lower is better.

### 3. Forecast Evaluation Metrics
* **RMSE (Root Mean Squared Error)**: Standard deviation of forecast residuals. Because errors are squared before averaging, RMSE heavily penalizes large forecast blunders. Measured in $\mu\text{g/m}^3$.
* **MAE (Mean Absolute Error)**: Average absolute magnitude of errors. More robust to occasional outlier spikes than RMSE. Measured in $\mu\text{g/m}^3$.
* **MAPE (Mean Absolute Percentage Error)**: Average error expressed as a percentage of actual values. Provides an intuitive gauge of relative accuracy ($6.15\%$ in our champion model).
* **Prediction Intervals (80% & 95%)**: Shaded confidence bands showing the statistical range within which future actual observations are expected to fall based on model error variance.

### 4. Dimensional Modeling & BI Terminology
* **Star Schema**: A database design where a central Fact table containing measurable numeric observations connects directly to surrounding Dimension tables containing descriptive attributes.
* **Fact Table**: Contains quantitative time-series metrics (e.g., `PM2.5`, `CO2`, `Temperature`, `Vehicle_Count`).
* **Dimension Table**: Contains entity context (e.g., GPS coordinates, location classifications, calendar attributes).
* **Grain**: The fundamental atomic level of detail in a fact table (here: 1 record per Location per Hour).
* **DAX (Data Analysis Expressions)**: The native functional formula language used in Microsoft Power BI to calculate dynamic measures and aggregations.
* **VertiPaq Engine**: Power BI's columnar in-memory database engine, optimized for rapid aggregations over star schemas.

---

## 💼 Grounded Technical Interview Guide

Here are 8 comprehensive interview questions and model answers demonstrating deep mastery of this project's code, statistics, and engineering trade-offs.

---

### Q1: Can you walk me through the end-to-end architecture of this air quality project?
**Model Answer:**
> "The project is structured into three decoupled tiers:
> 1. **Data Synthesis (Python)**: Implemented in `generate_synthetic_air_quality.py` using only the Python standard library. It simulates hourly physics—diurnal solar cycles, thermal boundary layer inversions, vehicular Gaussian rush hours, human metabolic respiration, and sensor noise—generating 70,080 rows for 2025 and 17,280 holdout rows for Q1 2026 across 8 campus micro-climates.
> 2. **Statistical Pipeline (R)**: Implemented in `run_analysis_and_forecast.R`. It flags sensor saturation errors ($> 500\ \mu\text{g/m}^3$), applies localized linear time-series interpolation (`zoo::na.approx`), conducts Augmented Dickey-Fuller stationarity tests, and trains three models: a baseline $\text{ARIMA}(2,0,0)$, a seasonal $\text{SARIMA}(1,0,2)(1,1,0)_{[24]}$, and an exogenous $\text{SARIMAX}$ incorporating traffic and wind regressors.
> 3. **Consumption & BI Layer**: Exports a clean Kimball Star Schema (`fact_air_quality_hourly`, `dim_location`, `dim_calendar`, `fact_forecast_24h`) for Microsoft Power BI executive dashboards, alongside a zero-dependency HTML5/JavaScript dashboard (`dashboard.html`) built with Chart.js and Leaflet for cross-platform browser visualization."

---

### Q2: Why did standard ARIMA fail for this use case, and how did SARIMA/SARIMAX solve it?
**Model Answer:**
> "When evaluating a 24-hour day-ahead forecast horizon, standard non-seasonal $\text{ARIMA}(2,0,0)$ captures only immediate temporal momentum (lags $t-1$ and $t-2$). After 2 to 3 hours, its autoregressive terms decay to zero, flattening into an uninformative mean line with a high RMSE of $13.32\ \mu\text{g/m}^3$.
>
> In reality, air quality is governed by a 24-hour diurnal cycle ($s = 24$) driven by morning/evening traffic rushes and nocturnal thermal inversions. $\text{SARIMA}(1,0,2)(1,1,0)_{[24]}$ incorporates seasonal polynomials and a seasonal differencing operator $(1 - B^{24})$, cutting RMSE by **$46.5\%$** down to $7.12\ \mu\text{g/m}^3$.
>
> Finally, moving to $\text{SARIMAX}$ allowed us to incorporate causal physical drivers: vehicular combustion volume increases particulate emissions, while surface wind speed drives atmospheric dispersion. Adding these regressors lowered the RMSE further to **$6.05\ \mu\text{g/m}^3$** and achieved a MAPE of **$6.15\%$**."

---

### Q3: Why did you train your models on a trailing 14-day window rather than the full 365 days of 2025?
**Model Answer:**
> "This was a deliberate engineering decision based on seasonal non-stationarity and computational efficiency:
> 1. **Seasonal Regime Shifts**: In ambient air quality, atmospheric chemistry changes drastically across seasons—monsoon rainout in July vs. winter thermal inversions in December. Fitting a seasonal model on summer data to predict January induces massive structural bias in the baseline and error variance.
> 2. **Diurnal Stability**: A 14-day trailing window provides 336 hourly observations. This represents exactly 14 full diurnal cycles, which is statistically sufficient for the seasonal differencing operator $(1 - B^{24})$ to stabilize without overfitting to distant historical weather regimes.
> 3. **Computational Scalability**: Restricting training to 336 rows guarantees that parameter estimation via `auto.arima()` converges in under 2 seconds, making the model suitable for automated, scheduled daily retraining in production."

---

### Q4: How did you prevent data leakage in your time-series pipeline?
**Model Answer:**
> "We enforced strict temporal ordering across all four transformation steps:
> 1. **Chronological Splitting**: We avoided random $k$-fold cross-validation. The training set strictly predates the test set; training uses the trailing 14 days of 2025, and holdout evaluation uses the first 24 hours of 2026.
> 2. **Independent Imputation**: The `clean_dataset()` function is called independently on the 2025 and 2026 raw datasets. No future test observations are available when interpolating missing values in the historical training set.
> 3. **Right-Aligned Moving Averages**: The 24-hour moving average uses `zoo::rollapply(..., align = 'right')`, ensuring that the moving average at hour $t$ only uses observations from $t-23$ to $t$ without looking ahead.
> 4. **Exogenous Regressors**: In our benchmark, test covariates simulate operational weather and traffic forecasts. We documented this operational dependency explicitly rather than assuming zero-latency empirical measurements."

---

### Q5: Why didn't you drop missing sensor rows (`na.omit`) or impute with the annual column mean?
**Model Answer:**
> "In time-series modeling, **row deletion (`na.omit`) is fatal**. Autoregressive models rely on an unbroken, uniform time grid ($t, t-1, t-2$). Dropping rows creates variable time gaps, destroying the lag operators and corrupting the 24-hour seasonal periodicity.
>
> On the other hand, **global mean imputation** is inappropriate for cyclic telemetry. Replacing a missing 04:00 AM reading with an annual average of $62\ \mu\text{g/m}^3$ artificially introduces severe step-function discontinuities.
>
> Instead, we grouped data by `Location` and applied linear interpolation using `zoo::na.approx(..., rule = 2)`. Because low-cost sensor dropouts are typically short (1–3 hours), linear interpolation preserves the diurnal slope and temporal continuity without corrupting the time index."

---

### Q6: How do you handle future values of exogenous variables (traffic and wind) in a production deployment?
**Model Answer:**
> "A $\text{SARIMAX}$ model requires values for external regressors ($X_{t+1}, \dots, X_{t+h}$) over the entire forecast horizon $h$. In a live operational campus system, we cannot measure tomorrow's traffic or wind speed empirically today.
>
> We resolve this through operational forecasting:
> 1. **Wind Speed & Meteorology**: Sourced from high-resolution Numerical Weather Prediction (NWP) APIs (e.g., Open-Meteo or ECMWF forecasts).
> 2. **Vehicle Counts**: Sourced from an empirical campus gate schedule model that forecasts traffic as a function of the day of the week, academic calendar events, and historical rush-hour profiles.
> In our operational script [`predict_tomorrow_24h.R`](../predict_tomorrow_24h.R), the pipeline ingests these predicted external inputs to produce tomorrow's 24-hour alert schedule."

---

### Q7: Why did you build both a Power BI Star Schema and a standalone HTML5/JS dashboard?
**Model Answer:**
> "They serve two distinct stakeholder personas and operational environments:
> 1. **Microsoft Power BI**: Designed for campus administrative leadership and safety officers. By establishing a Kimball Star Schema (`fact_air_quality_hourly`, `dim_location`, `dim_calendar`), administrators can slice and dice by facility type, review multi-year compliance trends via DAX, and trigger automated emergency workflows using Microsoft Power Automate.
> 2. **HTML5/JS Dashboard (`dashboard.html`)**: Power BI Desktop is Windows-only. To provide immediate, cross-platform accessibility on macOS, Linux, and campus display kiosks, we built a zero-dependency web visualizer using Leaflet.js for interactive mapping and Chart.js for forecast curves and 95% confidence bands. It runs locally with zero installation overhead."

---

### Q8: What technical steps are required to transition this system from synthetic simulation to physical IoT sensors?
**Model Answer:**
> "The transition requires four architectural adaptations:
> 1. **Edge Ingestion Layer**: Deploy low-cost IoT nodes (e.g., ESP32 microcontrollers paired with Plantower PMS5003 $\text{PM}_{2.5}$ optical sensors and Sensirion NDIR $\text{CO}_2$ sensors) publishing telemetry via MQTT to a campus broker (e.g., EMQX or Mosquitto).
> 2. **Time-Series Database**: Store incoming telemetry in an optimized time-series store (such as TimescaleDB or InfluxDB) with automated retention policies and continuous aggregate rollups.
> 3. **Environmental Sensor Corrections**: Real optical particulate sensors suffer from hygroscopic swelling in high humidity ($\text{RH} > 75\%$). The ingestion pipeline must apply empirical hygroscopic growth equations (e.g., $\kappa$-Köhler theory) to adjust raw optical counts based on co-located humidity sensors.
> 4. **Automated Scheduled Retraining**: Containerize `run_analysis_and_forecast.R` in Docker and orchestrate it via Apache Airflow or a cron daemon to retrain daily on the trailing 14-day rolling window, publishing fresh predictions directly to the database."
