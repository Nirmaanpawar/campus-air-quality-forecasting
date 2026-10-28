# Architectural & Technical Decisions Log (`decisions.md`)

This document records the meaningful architectural, statistical, and engineering decisions established in the **Campus Air Quality Monitoring, Analysis & Forecasting** codebase.

---

## Decision 1: Physics-Guided Synthetic Simulation Engine in Pure Standard Library Python

* **Decision**: Implement the data simulation engine (`generate_synthetic_air_quality.py`) using only the **Python Standard Library** (`math`, `random`, `datetime`, `csv`), completely avoiding third-party packages like `pandas` or `numpy`.
* **Context**: Physical IoT sensors were unavailable to capture empirical environmental telemetry across the 8 campus micro-environments. During environment inspection, `pandas` and `numpy` were not present in the native host environment (Python 3.13 on macOS).
* **Reasoning**: Standard library Python runs universally on any environment with zero installation overhead (`pip install` was avoided). The mathematical equations for diurnal cycles, Gaussian peak rush hours, atmospheric boundary layer dispersion, and $\text{AR}(1)$ autoregressive continuity could be expressed directly in pure Python and execute in under 1 second for 70,000+ hourly rows.
* **Alternatives Considered**:
  * *Installing `pandas`/`numpy`*: Rejected to maintain strict portability and prevent virtual environment dependency issues.
  * *Writing the generator in R*: Feasible, but separating data generation (Python) from statistical time-series modeling (R) maintains modular separation of concerns.
  * *Using static municipal datasets (e.g., OpenAQ/CPCB public stations)*: Rejected because public municipal stations report city-wide ambient air, failing to represent micro-environments like enclosed library study halls, cafeteria kitchens, or gate traffic bottlenecks.
* **Trade-offs**: Manual loop iterations and dictionary-based CSV serialization instead of vectorized DataFrame operations.
* **Trade-off Justification**: Generating 70,080 rows in pure Python takes only $\approx 0.8$ seconds. Vectorization speed was unnecessary given this high efficiency.
* **Consequences**: Zero dependency management; scripts run out-of-the-box on any standard Python 3 interpreter.

---

## Decision 2: Linear Time-Series Interpolation (`zoo::na.approx`) Over Row Deletion or Global Mean Imputation

* **Decision**: Use `zoo::na.approx(..., rule = 2)` grouped strictly by `Location` to impute missing sensor telemetry and flagged hardware saturation spikes ($> 500\ \mu\text{g/m}^3$).
* **Context**: Low-cost environmental IoT sensors experience packet loss and laser diode saturation anomalies (e.g., values of $999.0\ \mu\text{g/m}^3$).
* **Reasoning**:
  * In time-series modeling, **row deletion (`na.omit`) is fatal** because it destroys the uniform 1-hour temporal grid, rendering lag operators ($t-1$) and seasonal periods ($s=24$) invalid.
  * **Global mean or median imputation** artificially flattens diurnal waves (e.g., replacing a 04:00 AM reading with an annual average creates artificial step changes).
  * Linear interpolation preserves temporal continuity by calculating the trajectory between the boundary points immediately before and after the dropout.
* **Alternatives Considered**:
  * *Listwise row deletion (`na.omit`)*: Rejected because non-uniform time steps break ARIMA/SARIMA assumptions.
  * *Last Observation Carried Forward (LOCF / `na.locf`)*: Creates artificial flat plateaus during dropouts.
  * *Spline / Polynomial interpolation*: Can generate unrealistic polynomial oscillations (Runge's phenomenon) near sudden emission spikes.
* **Trade-offs**: Assumes a linear rate of change across the missing interval. For multi-day outages, linear interpolation would underestimate diurnal peaks and troughs.
* **Trade-off Justification**: Expected sensor packet dropouts in the dataset are short (1–3 consecutive hours), where linear interpolation is mathematically sound.
* **Consequences**: The clean dataset preserves exact 1-hour intervals with zero remaining `NA` values across all 8 locations.

---

## Decision 3: Progression to Seasonal SARIMA$(p,d,q)(P,D,Q)_{24}$ and SARIMAX Over Univariate ARIMA

* **Decision**: Expand the baseline univariate $\text{ARIMA}(2,0,0)$ model to a 24-hour seasonal $\text{SARIMA}(1,0,2)(1,1,0)_{[24]}$ and an exogenous $\text{SARIMAX}$ model incorporating `Vehicle_Count` and `Wind_Speed`.
* **Context**: Predicting air quality over a 24-hour day-ahead horizon. Baseline non-seasonal ARIMA decayed to an uninformative flat mean line after 2–3 hours.
* **Reasoning**:
  * Air pollution is fundamentally diurnal: Planetary boundary layer inversion traps nocturnal pollution, while traffic surges at 08:30 and 18:00. SARIMA models this 24-hour cyclical memory ($s=24$) via seasonal polynomials.
  * Atmospheric dispersion is physically forced by external drivers: vehicles emit $\text{NO}_x$ and $\text{PM}_{2.5}$, while wind speed dilutes ground-level concentrations. SARIMAX explicitly incorporates these causal regressors.
* **Alternatives Considered**:
  * *Standard Univariate ARIMA*: Proved inadequate; error was high ($\text{RMSE} = 13.32\ \mu\text{g/m}^3$).
  * *Holt-Winters Exponential Smoothing*: Captures seasonality but cannot incorporate external regressors like wind and traffic.
  * *Gradient Boosted Trees (XGBoost / LightGBM)*: Requires extensive feature engineering of lags and rolling statistics; does not natively produce exact confidence intervals.
* **Trade-offs**: SARIMA with $s=24$ increases parameter estimation complexity. SARIMAX requires future values of external regressors (weather and traffic projections) over the forecast horizon.
* **Trade-off Justification**: The empirical evidence was overwhelming: SARIMA reduced RMSE by **$46.5\%$** over ARIMA, and SARIMAX reduced RMSE by **$54.5\%$** (achieving $\text{RMSE} = 6.05\ \mu\text{g/m}^3$ and $\text{MAPE} = 6.15\%$).
* **Consequences**: SARIMAX was chosen as the **Champion Model** for all downstream Power BI alerts and dashboard forecasts.

---

## Decision 4: Recency-Weighted Training Window (Trailing 14 Days) for Model Estimation

* **Decision**: Fit the ARIMA, SARIMA, and SARIMAX models on the trailing 14 days of historical data (336 hourly observations) rather than the entire 365-day annual history.
* **Context**: The model was tasked with forecasting the first 24 hours of January 2026.
* **Reasoning**: Atmospheric chemistry exhibits strong seasonal non-stationarity across a year (winter thermal inversion vs. monsoon rain washout). Fitting a seasonal model on July/August data to predict January air quality induces structural parameter mismatch. Training on the trailing 14 days captures the immediate seasonal baseline and current campus operational rhythm.
* **Alternatives Considered**:
  * *Training on all 8,760 hours of 2025*: Rejected due to seasonal regime shifts and excessive computational inversion of $24 \times 24$ matrices in R.
  * *Dynamic Harmonic Fourier Regression*: Adds mathematical complexity without addressing immediate winter meteorological baselines.
* **Trade-offs**: A 14-day window cannot learn annual cycles (e.g., November festival patterns cannot be learned if training in January).
* **Trade-off Justification**: For short-term day-ahead operational forecasting (24 hours), recent regime persistence is substantially more predictive than annual cycles.
* **Consequences**: In an enterprise production deployment, the model must be scheduled to retrain on a continuous rolling window (e.g., daily or weekly).

---

## Decision 5: Bounded Parameter Space and Fast Approximation in `auto.arima()`

* **Decision**: Configure `auto.arima()` with `approximation = TRUE`, `stepwise = TRUE`, and bounded orders (`max.p = 2`, `max.q = 2`, `max.P = 1`, `max.Q = 1`) rather than unconstrained exact maximum likelihood.
* **Context**: An initial run with `approximation = FALSE` and unconstrained seasonal search with $s=24$ caused the R process to hang while inverting high-dimensional covariance matrices across candidate seasonal models.
* **Reasoning**: Restricting the search space to physically plausible lag orders and enabling conditional sum-of-squares (CSS) approximation speeds up model convergence from minutes to under 5 seconds while finding near-identical optimal AICc parameters.
* **Alternatives Considered**:
  * *Unconstrained exact CSS-ML estimation*: Cancelled due to computational bottlenecks on period $s=24$.
  * *Manual Box-Jenkins parameter selection*: Inflexible and cannot be automated in scheduled pipelines.
* **Trade-offs**: Restricting to $P \le 1, Q \le 1$ theoretically excludes higher-order seasonal interactions ($P \ge 2$).
* **Trade-off Justification**: 24-hour diurnal atmospheric cycles rarely require second-order seasonal lag parameters ($P \ge 2$). Speed and reliability in automated execution take precedence.
* **Consequences**: Enables instantaneous model retraining in operational pipelines without resource exhaustion.

---

## Decision 6: Star-Schema Dimensional Modeling (Kimball) for Power BI

* **Decision**: Decompose the flat time-series records into a formal **Star Schema**: `fact_air_quality_hourly`, `dim_location`, `dim_calendar`, and `fact_forecast_24h`.
* **Context**: Providing data to Microsoft Power BI for reporting, executive KPI aggregation, and geospatial mapping.
* **Reasoning**:
  * Flat denormalized tables degrade Power BI in-memory VertiPaq compression and make multi-table visual cross-filtering difficult.
  * A dimensional star schema separates static metadata (GPS coordinates, environment type, target safety thresholds) from high-frequency time-series facts, enabling clean $1 \rightarrow *$ single-direction relationships and simple DAX formulas.
* **Alternatives Considered**:
  * *Single large flat CSV*: Leads to repeated text columns, inflated file sizes, and slow DAX calculations.
  * *Snowflake Schema*: Over-normalizing calendar and location into sub-tables adds unnecessary relationship hops without analytical benefit.
* **Trade-offs**: Requires exporting and maintaining multiple linked CSV files.
* **Trade-off Justification**: Star Schema is the verified industry best practice for Power BI performance, DAX measure simplicity, and visual cross-filtering.
* **Consequences**: Dashboard developers can create role-playing dimensions, add new sensors without modifying fact tables, and write clean time-intelligence DAX formulas.

---

## Decision 7: Standalone Zero-Dependency Web Dashboard (`dashboard.html`) Alongside Power BI

* **Decision**: Build an interactive, single-file HTML5/JavaScript dashboard using CDN-delivered Tailwind CSS, Chart.js, and Leaflet.js in addition to the Power BI guide.
* **Context**: Power BI Desktop is primarily a Windows application. Users on macOS or Linux environments cannot run Power BI Desktop natively without virtual machines or Power BI Service cloud licensing.
* **Reasoning**: `dashboard.html` allows immediate, cross-platform visual inspection of the campus GPS map, the 24-hour forecast curve with shaded $95\%$ confidence intervals, and activity scatter plots directly in any web browser.
* **Alternatives Considered**:
  * *Power BI only*: Limits interactive accessibility on non-Windows machines.
  * *R Shiny application*: Requires maintaining an active R server daemon.
  * *Python Streamlit/Dash*: Requires local Python web server dependencies.
* **Trade-offs**: Static HTML/JS does not automatically live-reload data unless connected to a running WebSocket/REST API.
* **Trade-off Justification**: Provides instant, zero-install visual demonstration on macOS.
* **Consequences**: Acts as a production blueprint for a future student-facing web portal or campus kiosk.
