-- 1. Establish the operational context
USE DATABASE PHARMA_LOGISTICS;
USE SCHEMA ANALYTICS;

-- 2. Build the Clean Transformed Shipments Table
CREATE OR REPLACE TABLE PHARMA_LOGISTICS.ANALYTICS.CLEAN_SHIPMENTS AS
SELECT 
    Shipment_ID,
    Product,
    
    -- Fix Text Anomalies: Strip trailing spaces and capitalise the first letter uniformly
    INITCAP(TRIM(Origin)) AS Clean_Origin,
    INITCAP(TRIM(Destination)) AS Clean_Destination,
    
    -- Handle Missing Values: Replace NULLs with an explicit fallback category
    COALESCE(Carrier, 'Unknown Carrier') AS Clean_Carrier,
    Spoiled_Flag,
    
    -- Fix Mismatched Date Formats: Attempt to parse Format A; if it fails, parse Format B
    COALESCE(
        TRY_TO_TIMESTAMP(Departure_Time, 'YYYY-MM-DD HH:MI:SS'),
        TRY_TO_TIMESTAMP(Departure_Time, 'DD/MM/YYYY HH:MI')
    ) AS Standardized_Departure_Time,
    
    -- Standardise the arrival timestamp 
    TRY_TO_TIMESTAMP(Arrival_Time, 'YYYY-MM-DD HH:MI:SS') AS Standardized_Arrival_Time

FROM PHARMA_LOGISTICS.RAW.RAW_SHIPMENTS;

-- 3. Build the Clean Transformed Weather Table
CREATE OR REPLACE TABLE PHARMA_LOGISTICS.ANALYTICS.CLEAN_WEATHER AS
SELECT 
    INITCAP(TRIM(Hub_City)) AS Clean_Hub_City,
    TRY_TO_DATE(Date, 'YYYY-MM-DD') AS Standardized_Date,
    Max_Temp_C
FROM PHARMA_LOGISTICS.RAW.RAW_WEATHER;


SELECT * 
FROM PHARMA_LOGISTICS.ANALYTICS.CLEAN_SHIPMENTS 
LIMIT 15;


SELECT * 
FROM PHARMA_LOGISTICS.ANALYTICS.CLEAN_WEATHER 
LIMIT 15;