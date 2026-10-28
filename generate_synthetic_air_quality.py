#!/usr/bin/env python3
"""
Campus Air Quality & Activity Synthetic Data Generator
Generates realistic hourly environmental, traffic, and footfall data across campus locations.
Includes physically guided diurnal curves, meteorology, events, sensor noise, and realistic artifacts for cleaning.
"""

import csv
import math
import random
from datetime import datetime, timedelta

# Fix seed for reproducible scientific generation
random.seed(42)

LOCATIONS = [
    {"name": "Main Gate", "type": "traffic_gate", "base_veh": 140, "base_footfall": 90, "indoor": False},
    {"name": "Parking Lot", "type": "parking", "base_veh": 110, "base_footfall": 40, "indoor": False},
    {"name": "Back Gate Entry 1", "type": "secondary_gate", "base_veh": 75, "base_footfall": 65, "indoor": False},
    {"name": "Back Gate Entry 2", "type": "secondary_gate", "base_veh": 65, "base_footfall": 55, "indoor": False},
    {"name": "Library", "type": "indoor_study", "base_veh": 0, "base_footfall": 130, "indoor": True},
    {"name": "Canteen", "type": "indoor_dining", "base_veh": 5, "base_footfall": 160, "indoor": True},
    {"name": "Hostel Area", "type": "residential", "base_veh": 20, "base_footfall": 110, "indoor": False},
    {"name": "Playground", "type": "recreational", "base_veh": 0, "base_footfall": 85, "indoor": False},
]

def get_day_type(dt):
    """Categorizes the day into Event classes: Normal, Festival, Holiday, Exam_Week"""
    m, d, weekday = dt.month, dt.day, dt.weekday()
    
    # Major festival window (e.g. Autumn Diwali/Fest season)
    if (m == 10 and d in range(20, 31)) or (m == 11 and d in range(1, 11)):
        if d in [21, 22, 24, 26, 27, 28, 29, 30, 31, 1, 2, 3, 6, 8, 9]:
            return "Festival"
        return "Holiday"
    
    # Spring cultural fest (late February)
    if m == 2 and d in [20, 21, 22]:
        return "Festival"
    
    # National & Calendar Holidays
    if (m == 1 and d in [1, 26]) or (m == 8 and d == 15) or (m == 10 and d == 2):
        return "Holiday"
    
    # Exam weeks (early December, mid May)
    if (m == 12 and 1 <= d <= 15) or (m == 5 and 5 <= d <= 20):
        return "Exam_Week"
    
    # Weekend schedule
    if weekday == 6:
        return "Holiday"
    
    return "Normal"

def get_pm25_category(pm25):
    """Air Quality Index Breakpoints for PM2.5 (ug/m3)"""
    if pm25 <= 30:
        return "Good"
    elif pm25 <= 60:
        return "Satisfactory"
    elif pm25 <= 90:
        return "Moderate"
    elif pm25 <= 120:
        return "Poor"
    elif pm25 <= 250:
        return "Very Poor"
    else:
        return "Severe"

def generate_dataset(start_date, end_date, output_filename, inject_cleaning_artifacts=True):
    # Burn-in: start 48 hours earlier to let AR states reach natural equilibrium
    burn_in_start = start_date - timedelta(hours=48)
    
    # Initial state initialization at realistic baselines
    ar_pm25 = {loc["name"]: 65.0 for loc in LOCATIONS}
    ar_co2 = {loc["name"]: 450.0 for loc in LOCATIONS}
    ar_nox = {loc["name"]: 25.0 for loc in LOCATIONS}
    
    fieldnames = [
        "Timestamp", "Location", "Location_Type", "PM2.5 (ug/m3)", "CO2 (ppm)",
        "NOx (ppb)", "Temperature (C)", "Relative_Humidity (%)", "Wind_Speed (m/s)",
        "Vehicle_Count", "Human_Footfall", "Event", "AQI_Category"
    ]
    
    rows = []
    curr_dt = burn_in_start
    
    while curr_dt <= end_date:
        h = curr_dt.hour
        m = curr_dt.month
        weekday = curr_dt.weekday()
        event = get_day_type(curr_dt)
        
        # --- Synoptic Meteorology ---
        if m in [12, 1, 2]:
            base_temp = 15.0
        elif m in [3, 4, 5]:
            base_temp = 32.0
        elif m in [6, 7, 8]:
            base_temp = 28.0
        else: # 9, 10, 11
            base_temp = 24.0
        
        # Diurnal temperature cycle: lowest at 05:00, peak at 14:00
        temp_diurnal = 6.0 * math.sin((h - 8) * math.pi / 12)
        temperature = round(base_temp + temp_diurnal + random.gauss(0, 0.6), 1)
        
        # Relative humidity: inverse to temperature
        base_rh = 75.0 if m in [6, 7, 8, 12, 1] else 50.0
        rh_diurnal = -18.0 * math.sin((h - 8) * math.pi / 12)
        relative_humidity = min(98.0, max(20.0, round(base_rh + rh_diurnal + random.gauss(0, 2.5), 1)))
        
        # Wind speed: calmer at night, breezier in afternoon
        wind_speed = round(max(0.4, 1.2 + 1.8 * max(0, math.sin((h - 7) * math.pi / 12)) + random.uniform(-0.2, 0.6)), 1)
        
        # Atmospheric boundary layer dispersion factor
        dispersion_factor = 0.75 + 0.45 * max(0, math.sin((h - 7) * math.pi / 12)) + (wind_speed * 0.1)
        
        # Regional background PM2.5 (winter thermal inversion vs monsoon rainout)
        if m in [11, 12, 1]:
            regional_pm25 = 85.0
        elif m in [6, 7, 8]:
            regional_pm25 = 25.0
        elif m in [9, 10]:
            regional_pm25 = 45.0
        else:
            regional_pm25 = 55.0
        
        for loc in LOCATIONS:
            loc_name = loc["name"]
            loc_type = loc["type"]
            is_indoor = loc["indoor"]
            
            # --- Activity & Footfall Dynamics ---
            rush_morning = math.exp(-((h - 8.5) ** 2) / 2.0)
            rush_evening = math.exp(-((h - 18.0) ** 2) / 2.5)
            gate_rush = rush_morning + rush_evening
            
            if event == "Holiday":
                veh_mult = 0.20
                foot_mult = 0.30
            elif event == "Festival":
                veh_mult = 1.6 if h >= 16 else 1.1
                foot_mult = 1.9 if h >= 15 else 1.2
            elif event == "Exam_Week":
                veh_mult = 0.85
                foot_mult = 1.45 if loc_type == "indoor_study" else 0.45
            else:
                veh_mult = 1.0
                foot_mult = 1.0
            
            if weekday == 5 and event == "Normal": # Saturday
                veh_mult *= 0.55
                foot_mult *= 0.65
            elif weekday == 6 and event == "Normal": # Sunday
                veh_mult *= 0.25
                foot_mult *= 0.35
            
            # Vehicle Count
            if loc["base_veh"] > 0:
                v_pattern = 0.12 + 0.88 * gate_rush
                vehicle_count = int(max(0, loc["base_veh"] * v_pattern * veh_mult + random.gauss(0, 6)))
            else:
                vehicle_count = 0
            
            # Human Footfall
            if loc_type == "indoor_dining": # Canteen
                canteen_peaks = (
                    0.65 * math.exp(-((h - 8.5) ** 2) / 1.0) +
                    1.00 * math.exp(-((h - 13.0) ** 2) / 1.5) +
                    0.90 * math.exp(-((h - 20.0) ** 2) / 1.5)
                )
                footfall = int(max(4, loc["base_footfall"] * canteen_peaks * foot_mult + random.gauss(0, 5)))
            elif loc_type == "indoor_study": # Library
                lib_curve = 1.0 / (1.0 + math.exp(-0.8 * (h - 8))) - 1.0 / (1.0 + math.exp(-0.8 * (h - 22)))
                lib_curve = max(0.04, lib_curve)
                footfall = int(max(2, loc["base_footfall"] * lib_curve * foot_mult + random.gauss(0, 6)))
            elif loc_type == "recreational": # Playground
                play_morning = math.exp(-((h - 7.0) ** 2) / 1.2)
                play_evening = math.exp(-((h - 17.5) ** 2) / 1.8)
                footfall = int(max(0, loc["base_footfall"] * (play_morning + play_evening) * foot_mult + random.gauss(0, 4)))
            elif loc_type == "residential": # Hostel
                hostel_curve = 0.9 if (h >= 21 or h <= 8) else 0.3
                footfall = int(max(6, loc["base_footfall"] * hostel_curve * foot_mult + random.gauss(0, 6)))
            else: # Gates & Parking
                footfall = int(max(3, loc["base_footfall"] * (0.2 + 0.8 * gate_rush) * foot_mult + random.gauss(0, 5)))
            
            # --- Physical Environmental Chemistry ---
            
            # 1. PM2.5
            if not is_indoor:
                local_traffic_pm = vehicle_count * 0.22
                ambient_pm = (regional_pm25 + local_traffic_pm) / dispersion_factor
                
                if event == "Festival" and (17 <= h or h <= 2):
                    ambient_pm += random.uniform(60, 120)
                elif event == "Festival":
                    ambient_pm += random.uniform(25, 50)
                
                # Hygroscopic swelling
                if relative_humidity > 75.0:
                    ambient_pm *= (1.0 + 0.005 * (relative_humidity - 75.0))
                
                target_pm25 = ambient_pm
            else:
                if loc_type == "indoor_dining":
                    cooking_surge = 28.0 * (
                        math.exp(-((h - 8.5) ** 2) / 1.0) +
                        math.exp(-((h - 13.0) ** 2) / 1.2) +
                        math.exp(-((h - 20.0) ** 2) / 1.2)
                    )
                    target_pm25 = (regional_pm25 * 0.45) / dispersion_factor + cooking_surge
                else:
                    # Library (HVAC filtering reduces outdoor infiltration to 35%)
                    target_pm25 = (regional_pm25 * 0.35) / dispersion_factor + (footfall * 0.06)
            
            # Autoregressive continuity AR(1)
            ar_pm25[loc_name] = 0.78 * ar_pm25[loc_name] + 0.22 * (target_pm25 + random.gauss(0, 3.5))
            pm25_val = round(max(5.0, min(380.0, ar_pm25[loc_name])), 1)
            
            # 2. CO2 (ppm)
            if not is_indoor:
                outdoor_co2 = 415.0 + (vehicle_count * 0.75) + random.gauss(0, 6.0)
                if event == "Festival":
                    outdoor_co2 += random.uniform(30, 80)
                target_co2 = outdoor_co2
            else:
                # Human respiration in enclosed spaces
                ventilation_factor = 0.65
                occupant_co2 = footfall * 4.2
                target_co2 = 415.0 + (occupant_co2 / ventilation_factor)
                if event == "Exam_Week" and loc_type == "indoor_study":
                    target_co2 += random.uniform(180, 320)
            
            ar_co2[loc_name] = 0.84 * ar_co2[loc_name] + 0.16 * (target_co2 + random.gauss(0, 10.0))
            co2_val = int(max(380.0, min(2400.0, ar_co2[loc_name])))
            
            # 3. NOx (ppb)
            if not is_indoor:
                nox_target = 12.0 + (vehicle_count * 0.40) / dispersion_factor
                if event == "Festival":
                    nox_target += random.uniform(12, 28)
            else:
                if loc_type == "indoor_dining":
                    nox_target = 16.0 + (canteen_peaks * 28.0)
                else:
                    nox_target = 7.0 + random.uniform(0, 5)
            
            ar_nox[loc_name] = 0.72 * ar_nox[loc_name] + 0.28 * (nox_target + random.gauss(0, 2.5))
            nox_val = int(max(5.0, min(160.0, ar_nox[loc_name])))
            
            aqi_cat = get_pm25_category(pm25_val)
            
            # Keep only rows after burn-in
            if curr_dt >= start_date:
                # Inject realistic data cleaning artifacts (~0.8% missing values, ~0.2% calibration spikes)
                # to justify the "Data Cleaning" milestone in the project
                final_pm25 = pm25_val
                final_co2 = co2_val
                final_nox = nox_val
                
                if inject_cleaning_artifacts:
                    rand_check = random.random()
                    if rand_check < 0.004:
                        final_pm25 = ""  # Missing sensor packet
                    elif rand_check < 0.007:
                        final_co2 = ""   # Missing CO2 reading
                    elif rand_check < 0.008:
                        final_pm25 = 999.0  # Sensor saturation error spike
                
                rows.append({
                    "Timestamp": curr_dt.strftime("%Y-%m-%d %H:%M:%S"),
                    "Location": loc_name,
                    "Location_Type": loc_type,
                    "PM2.5 (ug/m3)": final_pm25,
                    "CO2 (ppm)": final_co2,
                    "NOx (ppb)": final_nox,
                    "Temperature (C)": temperature,
                    "Relative_Humidity (%)": relative_humidity,
                    "Wind_Speed (m/s)": wind_speed,
                    "Vehicle_Count": vehicle_count,
                    "Human_Footfall": footfall,
                    "Event": event,
                    "AQI_Category": aqi_cat
                })
        
        curr_dt += timedelta(hours=1)
    
    with open(output_filename, mode="w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
        
    print(f"Generated {len(rows)} records in {output_filename}")

if __name__ == "__main__":
    # Generate Full Year 2025 Dataset (Training & EDA)
    start_2025 = datetime(2025, 1, 1, 0, 0, 0)
    end_2025 = datetime(2025, 12, 31, 23, 0, 0)
    generate_dataset(start_2025, end_2025, "campus_air_quality_hourly_2025.csv", inject_cleaning_artifacts=True)
    
    # Generate First Quarter 2026 Dataset (For 2026 Forecast Verification)
    start_2026 = datetime(2026, 1, 1, 0, 0, 0)
    end_2026 = datetime(2026, 3, 31, 23, 0, 0)
    generate_dataset(start_2026, end_2026, "campus_air_quality_hourly_2026_test.csv", inject_cleaning_artifacts=False)
