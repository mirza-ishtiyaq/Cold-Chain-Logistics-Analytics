# Pharmaceutical Cold-Chain Logistics: End-to-End Spoilage Analytics & Revenue Protection

![Dashboard Preview](./Assets/dashboard_preview.jpg)

## Executive Summary & Business Context
In pharmaceutical logistics, maintaining cold-chain compliance is critical. A single temperature breach can compromise life-saving products (mRNA vaccines, biologics, insulin) and cost millions in spoiled inventory. In this project, I engineered an end-to-end data pipeline analyzing **5,000 pharmaceutical shipments** across major Indian logistics hubs (Hyderabad, Mumbai, Delhi, Chennai, Bangalore).

The analysis addressed three primary executive questions:
1. **Financial Risk & Revenue Loss:** What is the total YTD financial impact of spoiled shipments?
2. **Root-Cause Identification:** Are product spoilages driven by ambient origin weather, 3PL carrier transit delays, or a fatal combination of both?
3. **Carrier Accountability & Action:** Which Third-Party Logistics (3PL) providers are failing SLAs, and how do we hold them financially accountable?

To solve this, I combined Python-based REST API data extraction with an enterprise **Snowflake SQL Data Mart** and a **Power BI Executive Command Center**.

---

## Technical Stack & Repository Architecture
* **Language / Orchestration:** Python (Open-Meteo REST API, Pandas, Data Generation)
* **Data Warehouse:** Snowflake (SQL Data Mart Architecture: `RAW` & `ANALYTICS` Schemas)
* **Business Intelligence:** Power BI (Import Mode / Exception Reporting UX)

```
Cold-Chain-Logistics-Analytics/
├── README.md                                          # Documentation & executive insights
├── Assets/
│   └── dashboard_preview.jpg                          # Power BI Executive Dashboard Preview
├── Dashboard/
│   └── Cold_Logistics_Financial_Loss_Analysis.pbix    # Interactive Power BI Report
├── SQL_Scripts/
│   ├── 01_setup_raw_layer.sql                        # Snowflake DDL for RAW tables
│   ├── 02_data_cleaning_and_transformation.sql       # SQL cleaning, trimming & date parsing
│   └── 03_business_logic_modeling.sql                # Data Mart join logic & loss calculations
├── API_Weather_Dataset_Script/
│   └── pharma_shipments_Analysis.ipynb                # Weather API fetch & synthetic data pipeline
└── Raw_Dataset/
    ├── Parma_Dataset/
    │   └── dirty_pharma_shipments.csv                 # 5,000 raw shipment records
    └── Weather_Dataset/
        └── jan_2026_to_July_2026_Dataset.csv          # Historical hub temperature telemetry
```

---

## Pipeline Data Flow

```text
  [Open-Meteo REST API]              [Enterprise ERP Shipment Logs]
            │                                      │
            └───────────────┬──────────────────────┘
                            ▼
      🟤 RAW LAYER        : Snowflake Staging Tables (`01_setup_raw_layer.sql`)
                            │
                            ▼ (Trimming Whitespace, Parsing Mixed Dates, Null Handling)
      ⚪ SILVER / CLEAN   : Sanitized Tables (`02_data_cleaning_and_transformation.sql`)
                            │
                            ▼ (Left Join on Hub/Date, Transit Hours & Product Loss Calculations)
      🟡 GOLD / DATA MART : Business Spoilage Model (`03_business_logic_modeling.sql`)
                            │
                            ▼ (Import Mode / Exception Reporting UX)
      📊 POWER BI         : Executive Spoilage Command Center
```

---

## Data Pipeline Deep-Dive

### 1. External Weather API Extraction (Python)
To test the hypothesis that ambient origin temperatures drive spoilage, I wrote a Python script in `pharma_shipments_Analysis.ipynb` querying the **Open-Meteo Historical Weather REST API** (`archive-api.open-meteo.com`). This fetched daily maximum temperatures (°C) across all 5 departure hubs for the analysis window.

```python
import requests
import pandas as pd

hubs = {
    'Hyderabad': (17.3850, 78.4867),
    'Mumbai': (19.0760, 72.8777),
    'Delhi': (28.7041, 77.1025),
    'Chennai': (13.0827, 80.2707),
    'Bangalore': (12.9716, 77.5946)
}

base_url = "https://archive-api.open-meteo.com/v1/archive"
all_weather_data = []

for city, coords in hubs.items():
    params = {
        "latitude": coords[0],
        "longitude": coords[1],
        "start_date": "2025-01-01",
        "end_date": "2025-06-30",
        "daily": "temperature_2m_max",
        "timezone": "Asia/Kolkata"
    }
    response = requests.get(base_url, params=params)
    if response.status_code == 200:
        data = response.json()
        for date, temp in zip(data['daily']['time'], data['daily']['temperature_2m_max']):
            all_weather_data.append({'Hub_City': city, 'Date': date, 'Max_Temp_C': temp})
```

### 2. Snowflake Data Sanitization (`02_data_cleaning_and_transformation.sql`)
Raw operational extracts contained text formatting anomalies (mixed date formats, trailing spaces, and missing carrier values). In Snowflake SQL, I normalized these fields:
* **Text Formatting:** Cleaned city names using `INITCAP(TRIM())`.
* **Null Handling:** Replaced missing carrier entries with `'Unknown Carrier'` via `COALESCE()`.
* **Robust Timestamp Parsing:** Handled mixed date formats (`YYYY-MM-DD HH:MI:SS` vs `DD/MM/YYYY HH:MI`) using `COALESCE(TRY_TO_TIMESTAMP(...))`.

```sql
CREATE OR REPLACE TABLE PHARMA_LOGISTICS.ANALYTICS.CLEAN_SHIPMENTS AS
SELECT 
    Shipment_ID,
    Product,
    INITCAP(TRIM(Origin)) AS Clean_Origin,
    INITCAP(TRIM(Destination)) AS Clean_Destination,
    COALESCE(Carrier, 'Unknown Carrier') AS Clean_Carrier,
    Spoiled_Flag,
    -- Parsing mixed date formats
    COALESCE(
        TRY_TO_TIMESTAMP(Departure_Time, 'YYYY-MM-DD HH:MI:SS'),
        TRY_TO_TIMESTAMP(Departure_Time, 'DD/MM/YYYY HH:MI')
    ) AS Standardized_Departure_Time,
    TRY_TO_TIMESTAMP(Arrival_Time, 'YYYY-MM-DD HH:MI:SS') AS Standardized_Arrival_Time
FROM PHARMA_LOGISTICS.RAW.RAW_SHIPMENTS;
```

### 3. Business Logic & Spoilage Data Mart (`03_business_logic_modeling.sql`)
In the final data mart layer, I joined shipments with departure weather by hub city and date (`TO_DATE(departure_time) = weather_date`). I then engineered two key metrics:
1. **Transit Duration in Hours:** `DATEDIFF(hour, departure, arrival)`
2. **Financial Loss (USD):** Product-specific cost modeling when `Spoiled_Flag = 1`:
   - COVID-19 mRNA Vaccine: **$5,000 / unit**
   - Humira (Adalimumab): **$3,500 / unit**
   - Insulin Glargine: **$1,200 / unit**
   - Amoxicillin: **$250 / unit**

```sql
CREATE OR REPLACE TABLE PHARMA_LOGISTICS.ANALYTICS.BUSINESS_SPOILAGE_MODEL AS 
SELECT
    s.shipment_id,
    s.product,
    s.clean_origin AS Origin_Hub,
    s.clean_destination AS Destination_Hub,
    s.clean_carrier AS Carrier,
    s.Spoiled_Flag,
    s.standardized_departure_time AS Departure_Time,
    s.standardized_arrival_time AS Arrival_Time,
    -- Transit duration in hours
    DATEDIFF(hour, s.standardized_departure_time, s.standardized_arrival_time) AS Transit_Time_Hours,
    w.Max_Temp_c AS Origin_Departure_Temp_C,
    -- Unit financial loss allocation
    CASE 
        WHEN s.Spoiled_Flag = 1 AND s.Product = 'COVID-19 mRNA Vaccine' THEN 5000
        WHEN s.Spoiled_Flag = 1 AND s.Product = 'Humira (Adalimumab)' THEN 3500
        WHEN s.Spoiled_Flag = 1 AND s.Product = 'Insulin Glargine' THEN 1200
        WHEN s.Spoiled_Flag = 1 AND s.Product = 'Amoxicillin' THEN 250
        ELSE 0 
    END AS Estimated_Loss_USD
FROM PHARMA_LOGISTICS.ANALYTICS.CLEAN_SHIPMENTS s
LEFT JOIN PHARMA_LOGISTICS.ANALYTICS.CLEAN_WEATHER w
    ON s.clean_origin = w.Clean_Hub_City
    AND TO_DATE(s.standardized_departure_time) = w.Standardized_Date;
```

---

## Executive Findings & Actionable Recommendations

### 📈 1. Financial Impact & Spoilage Rate
* **Total YTD Loss:** **$709,550** lost across **297 spoiled packages** out of 5,000 shipments.
* **Overall Spoilage Rate:** **5.94%** (exceeding the industry target benchmark of < 2.0%).

### 🌡️ 2. The "Thermal Danger Zone" (Root-Cause Proven)
Cross-analyzing transit time against origin departure temperature revealed a clear failure threshold:
* Spoilage rates surge exponentially when **Origin Departure Temperature > 30°C AND Transit Time > 40 Hours**.
* Standard cold-chain packaging insulated for 24-36 hours fails consistently under high ambient heat when transit exceeds 40 hours.

### 🚚 3. 3PL Carrier Performance & Accountability
* **Delhivery ($153K loss)** and **FedEx ($145K loss)** account for **~$298K (42% of total financial loss)** due to excessive transit delays on high-temp origin routes.

### 💡 Strategic Recommendations for Supply Chain Leadership
1. **Recoup Lost Capital:** Immediately invoke SLA penalty clauses with Delhivery and FedEx to recover **~$298K** in documented carrier delays.
2. **Dynamic Packaging SOP:** Mandate heavy-duty thermal insulation (>72-hr rating) for all shipments departing hubs where ambient temperatures exceed 30°C on routes with expected transit times over 40 hours.

---

## Author & Project Info
* **Author:** Mirza Ishtiyaq Baig *(Data Analyst / Analytics Engineer)*
* **Repository:** `Cold-Chain-Logistics-Analytics`
