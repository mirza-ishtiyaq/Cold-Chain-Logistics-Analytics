# Data Dictionary — Pharmaceutical Cold-Chain Spoilage Analytics

This document provides field-level documentation for every data source and derived table used in the pipeline.

---

## Source Files

### `data/raw/dirty_pharma_shipments.csv`

**Description:** Raw ERP extract of 5,000 pharmaceutical shipment records across 5 Indian logistics hubs. Contains deliberate quality defects (mixed date formats, duplicate Shipment_IDs with conflicting field values, null carriers) representative of real production data issues.

| Column | Type | Description | Known Quality Issues |
|---|---|---|---|
| `Shipment_ID` | `VARCHAR` | Unique shipment identifier (format: `SHP-XXXXX`) | **124 IDs appear more than once** — 84 disagree on `Product`, 14 disagree on `Spoiled_Flag`. These are conflicting records, not clean re-sends. |
| `Product` | `VARCHAR` | Pharmaceutical product name | Values: `COVID-19 mRNA Vaccine`, `Humira (Adalimumab)`, `Insulin Glargine`, `Amoxicillin` |
| `Origin` | `VARCHAR` | Departure hub city | Values: `Hyderabad`, `Mumbai`, `Delhi`, `Chennai`, `Bangalore`. Contains trailing whitespace and inconsistent casing. |
| `Destination` | `VARCHAR` | Arrival hub city | Same values and quality issues as `Origin`. |
| `Carrier` | `VARCHAR` | Third-party logistics (3PL) provider | Values: `BlueDart`, `Delhivery`, `DHL`, `FedEx`, `Shadowfax`. **Contains NULLs** — imputed to `'Unknown Carrier'` in the CLEAN layer. |
| `Spoiled_Flag` | `INT` | Binary indicator: `1` = product spoiled during transit, `0` = intact | 297 of 5,000 shipments flagged as spoiled (5.94% spoilage rate). |
| `Departure_Time` | `VARCHAR` (text) | Timestamp of shipment departure from origin hub | **Mixed formats:** ISO (`YYYY-MM-DD HH:MI:SS`) and UK standard (`DD/MM/YYYY HH:MI`). Parsed via `COALESCE(TRY_TO_TIMESTAMP(...))` in the CLEAN layer. |
| `Arrival_Time` | `VARCHAR` (text) | Timestamp of shipment arrival at destination hub | ISO format only (`YYYY-MM-DD HH:MI:SS`). |

---

### `data/raw/jan_2025_to_july_2025_dataset.csv`

**Description:** Historical daily maximum temperature (°C) data pulled from the **Open-Meteo Historical Weather REST API** for all 5 departure hubs. Covers **January 2025 – June 2025** only.

| Column | Type | Description | Known Quality Issues |
|---|---|---|---|
| `Hub_City` | `VARCHAR` | Weather observation hub city | Values: `Hyderabad`, `Mumbai`, `Delhi`, `Chennai`, `Bangalore` |
| `Date` | `VARCHAR` (text) | Date of observation (`YYYY-MM-DD`) | Parsed to `DATE` via `TRY_TO_DATE()` in the CLEAN layer. |
| `Max_Temp_C` | `FLOAT` | Daily maximum ambient temperature in degrees Celsius | No nulls observed. |

> **Coverage gap:** Weather data covers Jan–Jun 2025 only. Shipment departure dates run through Jan 2026. This means only **~49% (2,446 / 5,000)** of shipments successfully join to a weather record. Any temperature-driven finding is backed by roughly half the population — documented as a caveat, not hidden.

---

## Snowflake Warehouse Tables

### RAW Layer (`PHARMA_LOGISTICS.RAW`)

| Table | Source | Row Count |
|---|---|---|
| `RAW_SHIPMENTS` | `dirty_pharma_shipments.csv` | 5,000+ (includes duplicates) |
| `RAW_WEATHER` | `jan_2025_to_july_2025_dataset.csv` | ~905 rows (5 hubs × ~181 days) |

### CLEAN / ANALYTICS Layer (`PHARMA_LOGISTICS.ANALYTICS`)

| Table | Upstream | Transformations Applied |
|---|---|---|
| `CLEAN_SHIPMENTS` | `RAW_SHIPMENTS` | `INITCAP(TRIM())` on city names, `COALESCE()` null carrier imputation, `TRY_TO_TIMESTAMP()` mixed-format date parsing |
| `CLEAN_WEATHER` | `RAW_WEATHER` | `INITCAP(TRIM())` on hub city, `TRY_TO_DATE()` date parsing |

### GOLD / Business Layer (`PHARMA_LOGISTICS.ANALYTICS`)

| Table | Upstream | Key Derived Fields |
|---|---|---|
| `BUSINESS_SPOILAGE_MODEL` | `CLEAN_SHIPMENTS` LEFT JOIN `CLEAN_WEATHER` on (Origin Hub, Departure Date) | `Transit_Time_Hours` — `DATEDIFF(hour, departure, arrival)` |
| | | `Origin_Departure_Temp_C` — ambient temperature at origin on departure date |
| | | `Estimated_Loss_USD` — product-specific financial loss: COVID-19 mRNA Vaccine = $5,000, Humira = $3,500, Insulin Glargine = $1,200, Amoxicillin = $250 |

### Data Quality Views (`PHARMA_LOGISTICS.ANALYTICS`)

| View | Purpose |
|---|---|
| `DQ_DUPLICATE_SHIPMENTS` | Surfaces 124 `Shipment_ID` values with conflicting `Product` / `Spoiled_Flag` / `Carrier` across repeated rows |
| `DQ_WEATHER_JOIN_COVERAGE` | Reports the match rate between shipments and weather records (~49%) |

---

## Spoilage Threshold Business Rule

The pipeline tests the following operational hypothesis:

> **Excursion Threshold:** Shipments departing when **Origin Departure Temperature > 30°C** AND **Transit Time > 40 Hours** are at elevated spoilage risk.

- Result: Spoilage rate in the excursion group is **6.05%** vs **5.18%** in the control group.
- Statistical significance: **Not significant** at this sample size (chi-square p ≈ 0.41).
- Status: **Monitoring hypothesis** — not a confirmed root cause. Closing the weather-data coverage gap is required before this can be promoted to an actionable SOP.
