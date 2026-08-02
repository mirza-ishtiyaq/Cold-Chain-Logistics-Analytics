-- ====================================================================
-- PLATFORM ARCHITECTURE: SILVER LAYER (TRANSFORMATION & DATA SANITIZATION)
-- Objective: Sanitize text anomalies, handle missing values, and parse 
-- mixed string date formats into standardized Snowflake timestamps.
-- Engine: Snowflake
-- ====================================================================

USE DATABASE PHARMA_LOGISTICS;
USE SCHEMA ANALYTICS;

-- 1. Cleaned & Standardized Operational Shipments Entity
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

FROM PHARMA_LOGISTICS.RAW.RAW_SHIPMENTS;

-- 2. Cleaned & Standardized Hub Weather Telemetry
CREATE OR REPLACE TABLE PHARMA_LOGISTICS.ANALYTICS.CLEAN_WEATHER AS
SELECT 
    INITCAP(TRIM(Hub_City)) AS Clean_Hub_City,
    TRY_TO_DATE(Date, 'YYYY-MM-DD') AS Standardized_Date,
    Max_Temp_C
FROM PHARMA_LOGISTICS.RAW.RAW_WEATHER;