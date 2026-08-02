-- ====================================================================
-- PLATFORM ARCHITECTURE: GOLD LAYER (BUSINESS DATA MART & LOSS MODEL)
-- Objective: Construct presentation data mart joining shipment logs 
-- with origin departure weather, transit duration, and product valuation.
-- Engine: Snowflake
-- ====================================================================

USE DATABASE PHARMA_LOGISTICS;
USE SCHEMA ANALYTICS;

-- 1. Analytical Data Mart: Business Spoilage & Financial Model
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
    
    -- Metric 1: Transit Duration in Hours
    DATEDIFF(hour, s.Standardized_Departure_Time, s.Standardized_Arrival_Time) AS Transit_Time_Hours,
    
    -- Metric 2: Ambient Origin Departure Temperature (°C)
    w.Max_Temp_C AS Origin_Departure_Temp_C,
    
    -- Metric 3: Unit Financial Loss Allocation (USD)
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