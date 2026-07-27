USE DATABASE PHARMA_LOGISTICS;
USE SCHEMA ANALYTICS;


-- 2. Build the Final Presentation Table (The Data Mart)
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
    
    -- KPI 1: Operational Efficiency (Transit Time)
    -- Calculate the exact hours a package spent in transit
    DATEDIFF(hour, s.standardized_departure_time, s.STANDARDIZED_ARRIVAL_TIME) AS Transit_Time,
    
    -- KPI 2: The Chaos Element (Weather)
    -- Pulling in the temperature at the origin hub on the day the package left
    w.Max_Temp_c AS Origin_Departure_Temp_C,
    
    -- KPI 3: Financial Impact Logic
    -- Enterprise executives want to see dollars, not just flags.
    -- We assign estimated loss values based on the product type.
    CASE 
        WHEN s.Spoiled_Flag = 1 AND s.Product = 'COVID-19 mRNA Vaccine' THEN 5000
        WHEN s.Spoiled_Flag = 1 AND s.Product = 'Humira (Adalimumab)' THEN 3500
        WHEN s.Spoiled_Flag = 1 AND s.Product = 'Insulin Glargine' THEN 1200
        WHEN s.Spoiled_Flag = 1 AND s.Product = 'Amoxicillin' THEN 250
        ELSE 0 
    END AS Estimated_Loss_USD
    
FROM PHARMA_LOGISTICS.ANALYTICS.CLEAN_SHIPMENTS s
-- We use a LEFT JOIN to keep all shipments, even if the weather API failed to capture that day
LEFT JOIN PHARMA_LOGISTICS.ANALYTICS.CLEAN_WEATHER w
    ON s.clean_origin = w.CLEAN_HUB_CITY
    -- CRITICAL: We must convert the Timestamp to a Date to match the weather table's granularity
    AND TO_DATE(s.standardized_departure_time) = w.Standardized_Date; 

-- Verifying the Final Output
SELECT * 
FROM PHARMA_LOGISTICS.ANALYTICS.BUSINESS_SPOILAGE_MODEL
ORDER BY Estimated_Loss_USD DESC
LIMIT 15;


SELECT CURRENT_USER();