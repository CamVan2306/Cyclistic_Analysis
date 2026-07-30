# 🚴 Cyclistic Bike-Share Analysis: Understanding Member vs Casual Rider Behavior

## 📌 Project Overview

Cyclistic is a bike-sharing company seeking to increase annual memberships. The business challenge is to understand how casual riders and annual members use Cyclistic bikes differently and identify opportunities to convert casual riders into members.

This project analyzes over **5.7 million bike trips collected throughout 2024** to uncover behavioral differences between the two customer segments and provide data-driven marketing recommendations.

### Business Objectives

* Analyze usage patterns of annual members and casual riders.
* Identify key differences in ride behavior, timing, and location.
* Generate actionable recommendations to increase membership conversion rates.

---

## 🛠 Tools & Technologies

| Category        | Tools                                   |
| --------------- | --------------------------------------- |
| Data Cleaning   | Python, Pandas, NumPy, Jupyter Notebook |
| Data Analysis   | SQL Server (T-SQL)                      |
| Visualization   | Power BI                                |
| Version Control | Git & GitHub                            |

### Key Techniques

* Data Cleaning & Validation
* Exploratory Data Analysis (EDA)
* Common Table Expressions (CTEs)
* Window Functions (ROW_NUMBER, LAG)

---

## 🗂 Data Dictionary

The dataset contains records of individual rides. Below is the description of the columns used in this analysis, including features engineered during the data cleaning process:

| Column Name | Data Type | Description |
| :--- | :--- | :--- |
| `ride_id` | String | Unique alphanumeric identifier for each trip (Primary Key). |
| `rideable_type` | String | Type of vehicle used (`electric_bike`, `classic_bike`, `electric_scooter`). |
| `started_at` | Datetime | Date and time when the trip started. |
| `ended_at` | Datetime | Date and time when the trip ended. |
| `start_station_name` | String | Name of the station where the trip began. |
| `start_station_id` | String | Unique identifier for the starting station. |
| `end_station_name` | String | Name of the station where the trip ended. |
| `end_station_id` | String | Unique identifier for the ending station. |
| `start_lat` / `start_lng` | Float | Latitude and Longitude of the starting location. |
| `end_lat` / `end_lng` | Float | Latitude and Longitude of the ending location. |
| `member_casual` | String | Customer segment: `member` (annual subscriber) or `casual` (single-ride/day-pass user). |
| **`ride_length_minutes`** | Float | Total duration of the trip in minutes. |
| **`day_of_week`** | String | The day of the week the trip started (e.g., Monday, Tuesday). |
| **`hour`** | Integer | The hour of the day the trip started (0-23 format). |

---

## ⚙️ Data Processing Workflow

### 1. Data Collection & Access
* Combined 12 monthly Divvy trip datasets from 2024.
* Initial dataset contained over 5.8 million ride records.
* ⚠️ **Note on Dataset:** Due to GitHub's file size limits, the full 5.7M row cleaned dataset is not hosted directly in this repository. 
  * A smaller sample dataset (`sample_data.csv`) is provided for code testing.
  * Link dataset: https://www.kaggle.com/datasets/camvan23/cyclistic-data-2020-cleaned*

### 2. Data Cleaning (Python)

Key cleaning steps included:

* Merging monthly datasets.
* Handling missing station information (filling with 'On Street - Dockless').
* Removing records with missing coordinates.
* Removing invalid ride durations (<= 0 and < 1 minute).
* Eliminating duplicate ride IDs.
* Creating analytical features (`ride_length_minutes`, `day_of_week`, `hour`).

### 3. Data Analysis (SQL Server)

SQL was used to perform large-scale aggregations and behavioral analysis, including:

* Ride duration comparison.
* Seasonal trend analysis.
* Day-of-week and hourly usage patterns.
* Station popularity analysis.
* Month-over-month growth calculations using LAG().
* Peak-hour identification using ROW_NUMBER().

### 4. Dashboard Development (Power BI)

Interactive dashboards were created to visualize:

* Rider segmentation.
* Ride duration trends.
* Seasonal demand patterns.
* Popular stations.
* Weekly and hourly usage behavior.

*(📸 Insert Dashboard Screenshots Here)*

---

## 📊 Key Findings

### 1. Different Riding Purposes

* Members accounted for approximately 63.6% of total trips.
* Average ride duration:
  * Members: 12.4 minutes
  * Casual Riders: 21.7 minutes

Many casual riders started and ended their trips at the same station, indicating recreational usage.

**Insight:** Members primarily use bikes for commuting, while casual riders are more likely to use bikes for leisure and tourism.

---

### 2. Strong Temporal Differences

* Casual riders peak during weekends.
* Members peak during weekday commuting hours.
* Casual rider activity reaches its highest level around 3:00 PM.
* Member activity peaks around 5:00 PM.

Seasonal growth among casual riders increases significantly during warmer months, with strong increases observed in April and May.

**Insight:** Casual usage is highly influenced by weather and leisure activities, whereas member usage is more consistent throughout the year.

---

### 3. Location-Based Behavior

Analysis of the most popular stations revealed that casual riders heavily concentrate around waterfront, park, and tourist areas.

**Insight:** Casual demand is geographically concentrated around recreational destinations.

---

## 💡 Business Recommendations

### 1. Seasonal Membership Plans

Introduce flexible membership packages designed specifically for casual riders, such as:

* Summer Membership
* Weekend Membership
* Three-Month Membership

This reduces commitment barriers associated with annual subscriptions.

---

### 2. Location-Based Marketing

Focus marketing campaigns around the most popular casual-rider stations through:

* On-site promotions
* Pop-up registration booths
* Outdoor advertising near high-traffic recreational areas

---

### 3. Timed Digital Campaigns

Deploy app notifications, email campaigns, and promotional vouchers shortly before peak casual riding periods.

Suggested campaign window:

* Fridays and Saturdays
* Between 1:00 PM and 2:00 PM
* April through August

This timing aligns with observed demand peaks and maximizes campaign relevance.

---

## 📈 Project Outcomes

This project demonstrates the complete data analytics workflow:

* Data Cleaning with Python
* Data Exploration using SQL
* Dashboard Development with Power BI
* Business Insight Generation
* Data-Driven Decision Making

The analysis provides actionable recommendations that can support Cyclistic's goal of increasing annual memberships by targeting high-potential casual riders.
