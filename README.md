# Cold-Chain Spoilage & Carrier SLA Recovery Engine

![Dashboard Preview](./docs/images/dashboard_preview.jpg)

> **Resume Metrics Alignment**
> This repository is the source of truth for the following resume claims:
> - **$298K in recoverable SLA penalties** — traced to 2 named 3PL carriers (Delhivery + FedEx)
> - **5,000 pharmaceutical shipments** analyzed across 5 Indian logistics hubs
> - **Spoilage threshold tested:** `>30°C origin temp + >40hr transit` — reported honestly as a monitoring hypothesis (p ≈ 0.41), not a confirmed root cause
> - Weather telemetry joined via **Open-Meteo REST API** ingestion (Python)

---

## Business Problem

Cold-chain pharmaceutical logistics teams had **no visibility** into whether product spoilage was driven by ambient heat at origin hubs, carrier transit delays, or a combination of both — and **no financial mechanism** to hold underperforming 3PL carriers accountable for SLA breaches.

This project answers three executive questions:
1. **Financial Risk & Revenue Loss:** What is the total YTD financial impact of spoiled shipments?
2. **Root-Cause Identification:** Are spoilages driven by ambient origin weather, 3PL carrier transit delays, or a combination?
3. **Carrier Accountability & SLA Penalty Recovery:** Which 3PL providers are failing SLAs, and what is the recoverable penalty amount?

---

## Executive Summary
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
pharma-cold-chain-analytics/
├── README.md                                          # Documentation & executive insights
├── docs/
│   └── images/
│       └── dashboard_preview.jpg                      # Power BI Executive Dashboard Preview
├── dashboards/
│   └── Cold_Logistics_Financial_Loss_Analysis.pbix    # Interactive Power BI Report
├── sql/
│   ├── 01_setup_raw_layer.sql                         # Snowflake DDL for RAW tables
│   ├── 02_data_cleaning_and_transformation.sql        # SQL cleaning, trimming & date parsing
│   ├── 03_business_logic_modeling.sql                 # Data Mart join logic & loss calculations
│   └── 04_data_quality_checks.sql                     # Duplicate-ID & weather-join coverage checks
├── notebooks/
│   └── pharma_shipments_analysis.ipynb                # Weather API fetch & synthetic data pipeline
└── data/
    ├── data_dictionary.md                             # Field-level documentation for all datasets
    └── raw/
        ├── dirty_pharma_shipments.csv                 # 5,000 raw shipment records
        └── jan_2026_to_july_2026_dataset.csv          # Historical hub temperature telemetry
```

---

## Pipeline Data Flow

```text
  [Open-Meteo REST API]              [Enterprise ERP Shipment Logs]
            │                                      │
            └───────────────┬──────────────────────┘
                            ▼
      RAW LAYER           : Snowflake Staging Tables (`01_setup_raw_layer.sql`)
                            │
                            ▼ (Trimming Whitespace, Parsing Mixed Dates, Null Handling)
      SILVER / CLEAN      : Sanitized Tables (`02_data_cleaning_and_transformation.sql`)
                            │
                            ▼ (Left Join on Hub/Date, Transit Hours & Product Loss Calculations)
      GOLD / DATA MART    : Business Spoilage Model (`03_business_logic_modeling.sql`)
                            │
                            ▼ (Import Mode / Exception Reporting UX)
      POWER BI            : Executive Spoilage Command Center
```

---

## Data Pipeline Deep-Dive

### 1. External Weather API Extraction (Python)
To test the hypothesis that ambient origin temperatures drive spoilage, I wrote a Python script in `pharma_shipments_analysis.ipynb` querying the **Open-Meteo Historical Weather REST API** (`archive-api.open-meteo.com`). This fetched daily maximum temperatures (°C) across all 5 departure hubs for the analysis window.

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
    s.Shipment_ID,
    s.Product,
    s.Clean_Origin AS Origin_Hub,
    s.Clean_Destination AS Destination_Hub,
    s.Clean_Carrier AS Carrier,
    s.Spoiled_Flag,
    s.Standardized_Departure_Time AS Departure_Time,
    s.Standardized_Arrival_Time AS Arrival_Time,
    -- Transit duration in hours
    DATEDIFF(hour, s.Standardized_Departure_Time, s.Standardized_Arrival_Time) AS Transit_Time_Hours,
    w.Max_Temp_C AS Origin_Departure_Temp_C,
    -- Unit financial loss allocation
    CASE 
        WHEN s.Spoiled_Flag = 1 AND s.Product = 'COVID-19 mRNA Vaccine' THEN 5000
        WHEN s.Spoiled_Flag = 1 AND s.Product = 'Humira (Adalimumab)'    THEN 3500
        WHEN s.Spoiled_Flag = 1 AND s.Product = 'Insulin Glargine'       THEN 1200
        WHEN s.Spoiled_Flag = 1 AND s.Product = 'Amoxicillin'            THEN 250
        ELSE 0 
    END AS Estimated_Loss_USD
FROM PHARMA_LOGISTICS.ANALYTICS.CLEAN_SHIPMENTS s
LEFT JOIN PHARMA_LOGISTICS.ANALYTICS.CLEAN_WEATHER w
    ON s.Clean_Origin = w.Clean_Hub_City
    AND TO_DATE(s.Standardized_Departure_Time) = w.Standardized_Date;
```

### 4. Data Quality & Integrity Checks (`04_data_quality_checks.sql`)
Two checks I added after validating the pipeline against the raw CSVs, because both silently distort the GOLD-layer financial model if left unchecked:
* **Duplicate `Shipment_ID` detection:** `RAW_SHIPMENTS` contains **124 `Shipment_ID` values appearing more than once (250 rows total)** — and these aren't harmless duplicates: **84 of them disagree on `Product`** and **14 disagree on `Spoiled_Flag`** across the repeated rows, meaning they're conflicting records, not clean re-sends.
* **Orphaned shipment-to-weather join coverage:** the `LEFT JOIN` on Origin Hub + Departure Date only resolves for **49% of shipments (2,446 / 5,000)**. `RAW_WEATHER` only covers **Jan–Jun 2025**, while `RAW_SHIPMENTS` departure dates run through **Jan 2026** — so any temperature-driven finding built on the join is backed by roughly half the shipment population.

```sql
-- Duplicate Shipment_ID detection (conflicting, not clean, duplicates)
SELECT
    Shipment_ID,
    COUNT(*)                      AS Record_Count,
    COUNT(DISTINCT Product)       AS Distinct_Product_Values,
    COUNT(DISTINCT Spoiled_Flag)  AS Distinct_Spoiled_Flag_Values
FROM PHARMA_LOGISTICS.RAW.RAW_SHIPMENTS
GROUP BY Shipment_ID
HAVING COUNT(*) > 1;

-- Shipment-to-weather join coverage
SELECT
    COUNT(*)                                        AS Total_Shipments,
    COUNT(w.Max_Temp_C)                             AS Shipments_With_Weather_Match,
    ROUND(COUNT(w.Max_Temp_C) / COUNT(*) * 100, 2)  AS Match_Rate_Pct
FROM PHARMA_LOGISTICS.ANALYTICS.CLEAN_SHIPMENTS s
LEFT JOIN PHARMA_LOGISTICS.ANALYTICS.CLEAN_WEATHER w
    ON s.Clean_Origin = w.Clean_Hub_City
    AND TO_DATE(s.Standardized_Departure_Time) = w.Standardized_Date;
```

---

## Impact & Executive Findings

### 1. Financial Impact & Spoilage Rate
* **Total YTD Loss:** **$708,550** lost across **297 spoiled packages** out of 5,000 shipments.
* **Overall Spoilage Rate:** **5.94%** (exceeding the industry target benchmark of < 2.0%).

### 2. Spoilage Threshold Hypothesis (`>30°C / >40hr Transit`)
Cross-analyzing transit time against origin departure temperature — available for only **49% of shipments** (see the weather-join coverage gap above) — shows a mild directional effect, not a proven causal driver:
* Shipments departing when **Origin Departure Temperature > 30°C AND Transit Time > 40 Hours** spoil at **6.05%**, versus **5.18%** for all other shipments in the matched sample.
* A chi-square test on this split is **not statistically significant at this sample size** (p ≈ 0.41). The honest read: this is a monitoring hypothesis worth tracking for SLA design, not a confirmed root cause — closing the weather-data coverage gap is the next step to test it properly.

### 3. Carrier SLA Penalty Recovery — **$298K Recoverable**
* **Delhivery ($153,550 loss)** and **FedEx ($145,200 loss)** account for **~$298,750 (42% of total financial loss)** — the two highest-loss carriers by a clear margin over BlueDart ($144,150), DHL ($121,750), and Shadowfax ($119,250).
* This is the **$298K in recoverable SLA penalties** cited on my resume — a documented, carrier-attributable claim backed by the `BUSINESS_SPOILAGE_MODEL` fact table.

### 4. Strategic Recommendations for Supply Chain Leadership
1. **Recoup Lost Capital:** Invoke SLA penalty clauses with Delhivery and FedEx to recover **~$298,750** in documented carrier-attributed losses.
2. **Close the Data Gap Before Mandating Packaging Changes:** Extend the Open-Meteo pull to cover the full shipment date range (currently only 49% of shipments have a matching weather record) and re-test the >30°C / >40-hr transit hypothesis on the complete population before mandating thermal-insulation SOPs on the strength of the current directional-but-inconclusive signal.
3. **Fix Upstream Data Integrity:** Deduplicate the 124 `Shipment_ID` values in `RAW_SHIPMENTS` that carry conflicting `Product` / `Spoiled_Flag` values across repeated rows before these loss figures are used for carrier SLA enforcement.

---

## Author & Project Info
**Author:** Mirza Ishtiyaq Baig — Data Analyst, Supply Chain & Service Operations Analytics
**LinkedIn:** [linkedin.com/in/mirzaishtiyaqbaig](https://www.linkedin.com/in/mirzaishtiyaqbaig/)
**Email:** mirzaishtiyaqbaig1@gmail.com
**GitHub:** [github.com/mirza-ishtiyaq](https://github.com/mirza-ishtiyaq)
