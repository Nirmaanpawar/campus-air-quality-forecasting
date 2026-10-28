# Power BI Dashboard Implementation Guide: Campus Air Quality & Forecasting

This guide details how to build the complete, multi-page interactive Power BI dashboard using the generated star-schema tables.

---

## 1. Data Model (Star Schema)

Import the exported CSV files into Power BI Desktop (**Home -> Get Data -> Text/CSV**):

1. **`fact_air_quality_hourly.csv`** (Fact Table)
2. **`dim_location.csv`** (Dimension Table)
3. **`dim_calendar.csv`** (Dimension Table)
4. **`fact_forecast_24h.csv`** (Forecast Horizon Fact Table)
5. **`model_performance_metrics.csv`** (Model Accuracy Benchmarks)

### Relationships (Model View)
Set up the following relationships in the **Model View**:
* `dim_location[Location]` **(1)** ────► **(*)** `fact_air_quality_hourly[Location]` (Single direction)
* `dim_calendar[Timestamp]` **(1)** ────► **(*)** `fact_air_quality_hourly[Timestamp]` (Single direction)
* `dim_location[Location]` **(1)** ────► **(*)** `fact_forecast_24h[Location]` (Single direction)

---

## 2. Key DAX Measures

Create a dedicated Measures table (`_Measures`) and add the following DAX formulas:

### A. Core Metrics & Moving Averages
```dax
Avg_PM25 = 
AVERAGE(fact_air_quality_hourly[PM2.5])

Avg_CO2 = 
AVERAGE(fact_air_quality_hourly[CO2])

Avg_NOx = 
AVERAGE(fact_air_quality_hourly[NOx])

Total_Vehicle_Traffic = 
SUM(fact_air_quality_hourly[Vehicle_Count])

Total_Footfall = 
SUM(fact_air_quality_hourly[Human_Footfall])

24h_Rolling_Avg_PM25 = 
VAR CurrentTime = MAX(fact_air_quality_hourly[Timestamp])
RETURN
    CALCULATE(
        AVERAGE(fact_air_quality_hourly[PM2.5]),
        DATESINPERIOD(dim_calendar[Date], MAX(dim_calendar[Date]), -1, DAY)
    )
```

### B. Safety Exceedance & Compliance Counters
```dax
Hours_Exceeding_WHO = 
CALCULATE(
    COUNTROWS(fact_air_quality_hourly),
    fact_air_quality_hourly[PM2.5] > 60
)

Hazardous_Hours_Count = 
CALCULATE(
    COUNTROWS(fact_air_quality_hourly),
    fact_air_quality_hourly[PM2.5] > 120
)

Indoor_CO2_Breach_Hours = 
CALCULATE(
    COUNTROWS(fact_air_quality_hourly),
    fact_air_quality_hourly[CO2] > 1000,
    fact_air_quality_hourly[Location_Type] IN {"indoor_study", "indoor_dining"}
)
```

### C. Dynamic Early-Warning Status Flag
```dax
Campus_Air_Status_Alert = 
VAR CurrentPM = [Avg_PM25]
RETURN
    SWITCH(
        TRUE(),
        CurrentPM <= 30, "🟢 Good - Healthy Outdoor Activity",
        CurrentPM <= 60, "🟡 Moderate - Acceptable Quality",
        CurrentPM <= 90, "🟠 Sensitive Alert - Restrict Intensive Training",
        CurrentPM <= 120, "🔴 Unhealthy - Wear N95 Near Gates",
        "🟣 Severe - Hazardous: Restrict Outdoor Movement"
    )
```

---

## 3. Dashboard Page Architecture

### Page 1: Campus Environmental Executive Cockpit
* **Top Ribbon KPIs**:
  - `Campus Avg PM2.5` (Card with conditional green/yellow/red formatting)
  - `Max CO2 Reading` (Library / Canteen indicator)
  - `24h Total Vehicle Volume`
  - `Active Environmental Alert` (Card using `[Campus_Air_Status_Alert]`)
* **Visual 1: Geospatial Campus Map (Map / Azure Map visual)**:
  - Latitude: `dim_location[Latitude]`, Longitude: `dim_location[Longitude]`
  - Bubble Size: `[Avg_PM25]`, Color: `[Avg_PM25]` (diverging green to red gradient)
* **Visual 2: 24-Hour Diurnal Profile by Location**:
  - Line Chart: X-axis = `dim_calendar[Hour]`, Y-axis = `[Avg_PM25]`, Legend = `Location`
* **Slicers**:
  - Location Dropdown, Event Type (*Festival*, *Holiday*, *Normal*), Date Range Slider

### Page 2: Source Attribution & Activity Dynamics
* **Visual 1: Scatter Plot — Gate Traffic vs NOx & PM2.5**:
  - X-axis = `Vehicle_Count`, Y-axis = `NOx`, Size = `PM2.5`, Color by `Event`
* **Visual 2: Indoor Respiration Curve — Library & Canteen**:
  - Clustered Column Chart: X-axis = `Hour`, Column 1 = `Footfall`, Line = `CO2`
* **Visual 3: Matrix Table**:
  - Rows = `Location`, Columns = `AQI_Category`, Values = `% of Total Hours`

### Page 3: 24-Hour Predictive Forecasting & Early Warning
* **Visual 1: Forecast Horizon Line & Ribbon Chart**:
  - X-axis = `fact_forecast_24h[Timestamp]`
  - Values = `Actual_PM2.5`, `SARIMA_Pred`, `SARIMAX_Pred`
  - Prediction Bands = Shaded Area between `SARIMAX_Lower_95` and `SARIMAX_Upper_95`
* **Visual 2: Model Accuracy Comparison Table**:
  - Table Visual using `model_performance_metrics.csv` (Model, Specification, RMSE, MAE, MAPE)
* **Visual 3: Peak Warning Card**:
  - Displays the forecasted peak pollution hour and predicted concentration for the day ahead.

---

## 4. Automation & Alerts Configuration
* In Power BI Service, click the **`Campus_Air_Status_Alert`** or **`Hazardous_Hours_Count`** card visual.
* Select **Set Alert** -> Condition: `> 0`.
* Connect alert to **Power Automate** to trigger automated emails or Telegram messages to campus safety administrators.
