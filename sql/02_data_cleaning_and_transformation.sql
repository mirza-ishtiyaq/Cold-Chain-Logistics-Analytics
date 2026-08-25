-- ====================================================================
-- PLATFORM ARCHITECTURE: SILVER LAYER (TRANSFORMATION & DATA SANITIZATION)
-- Objective: Sanitize text anomalies, handle missing values, and parse 
-- mixed string date formats into standardized Snowflake timestamps.
-- Engine: Snowflake
-- ====================================================================

USE DATABASE PHARMA_LOGISTICS;
USE SCHEMA ANALYTICS;

-- 1. Cleaned & Standardized Operational Shipments Entity
-- Excludes the 124 conflicting duplicate Shipment_IDs identified in
-- 04_data_quality_checks.sql (DQ_DUPLICATE_SHIPMENTS) -- these rows
-- disagree with each other on Product and/or Spoiled_Flag, and with no
-- trustworthy load/ingest timestamp available to pick which version is
-- correct, keeping any one of them (or all of them) would inject an
-- unverifiable value into every downstream financial figure. Excluding
-- them entirely is the conservative choice until the source ERP can
-- supply a timestamp to disambiguate -- see the DQ view for the
-- reasoning and the exact IDs affected.
CREATE OR REPLACE TABLE PHARMA_LOGISTICS.ANALYTICS.CLEAN_SHIPMENTS AS
SELECT
    Shipment_ID,
    Product,

    -- Normalize Text: Strip whitespace and apply standard title casing
    INITCAP(TRIM(Origin)) AS Clean_Origin,
    INITCAP(TRIM(Destination)) AS Clean_Destination,

    -- Null Handling: Impute missing carrier values with explicit fallback
    COALESCE(Carrier, 'Unknown Carrier') AS Clean_Carrier,
    Spoiled_Flag,

    -- Temporal Normalization: Parse mixed date formats (ISO vs UK standard)
    COALESCE(
        TRY_TO_TIMESTAMP(Departure_Time, 'YYYY-MM-DD HH:MI:SS'),
        TRY_TO_TIMESTAMP(Departure_Time, 'DD/MM/YYYY HH:MI')
    ) AS Standardized_Departure_Time,

    TRY_TO_TIMESTAMP(Arrival_Time, 'YYYY-MM-DD HH:MI:SS') AS Standardized_Arrival_Time

FROM PHARMA_LOGISTICS.RAW.RAW_SHIPMENTS
WHERE Shipment_ID NOT IN (
    SELECT Shipment_ID FROM PHARMA_LOGISTICS.RAW.RAW_SHIPMENTS
    GROUP BY Shipment_ID HAVING COUNT(*) > 1
);

-- 2. Cleaned & Standardized Hub Weather Telemetry
CREATE OR REPLACE TABLE PHARMA_LOGISTICS.ANALYTICS.CLEAN_WEATHER AS
SELECT 
    INITCAP(TRIM(Hub_City)) AS Clean_Hub_City,
    TRY_TO_DATE(Date, 'YYYY-MM-DD') AS Standardized_Date,
    Max_Temp_C
FROM PHARMA_LOGISTICS.RAW.RAW_WEATHER;