-- ====================================================================
-- PLATFORM ARCHITECTURE: EXECUTIVE FINANCIAL SUMMARY
-- Objective: Roll BUSINESS_SPOILAGE_MODEL up into the headline
-- financial figures quoted in README.md, as real, runnable queries --
-- not numbers computed once in Power BI and pasted into documentation.
-- Engine: Snowflake
-- ====================================================================

USE DATABASE PHARMA_LOGISTICS;
USE SCHEMA ANALYTICS;

-- 1. Total YTD Loss & Overall Spoilage Rate
CREATE OR REPLACE VIEW PHARMA_LOGISTICS.ANALYTICS.VW_EXECUTIVE_SUMMARY AS
SELECT
    COUNT(*)                                          AS Total_Shipments,
    SUM(CASE WHEN Spoiled_Flag = 1 THEN 1 ELSE 0 END) AS Spoiled_Shipments,
    ROUND(SUM(CASE WHEN Spoiled_Flag = 1 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS Spoilage_Rate_Pct,
    SUM(Estimated_Loss_USD)                           AS Total_Loss_USD,
    SUM(CASE WHEN Carrier = 'Unknown Carrier' THEN Estimated_Loss_USD ELSE 0 END) AS Unknown_Carrier_Loss_USD
FROM PHARMA_LOGISTICS.ANALYTICS.BUSINESS_SPOILAGE_MODEL;

-- 2. Carrier SLA Penalty Recovery — loss ranked by carrier
CREATE OR REPLACE VIEW PHARMA_LOGISTICS.ANALYTICS.VW_CARRIER_LOSS_RANKING AS
SELECT
    Carrier,
    COUNT(*)                                 AS Shipments,
    SUM(CASE WHEN Spoiled_Flag = 1 THEN 1 ELSE 0 END) AS Spoiled_Shipments,
    SUM(Estimated_Loss_USD)                  AS Total_Loss_USD
FROM PHARMA_LOGISTICS.ANALYTICS.BUSINESS_SPOILAGE_MODEL
GROUP BY Carrier
ORDER BY Total_Loss_USD DESC;

-- 3. Top-2-carrier recoverable penalty amount, used directly in the
-- README's "Carrier SLA Penalty Recovery" figure — always re-derive
-- this from VW_CARRIER_LOSS_RANKING rather than hardcoding a carrier
-- name, since the ranking can change if the underlying data changes
-- (it did: the two highest-loss carriers shifted once the 124
-- conflicting Shipment_IDs were excluded upstream in
-- 02_data_cleaning_and_transformation.sql -- see git history on that
-- file and the README's Impact & Executive Findings section).
SELECT
    SUM(Total_Loss_USD) AS Top_2_Carrier_Recoverable_USD
FROM (
    SELECT Total_Loss_USD
    FROM PHARMA_LOGISTICS.ANALYTICS.VW_CARRIER_LOSS_RANKING
    WHERE Carrier != 'Unknown Carrier'
    ORDER BY Total_Loss_USD DESC
    LIMIT 2
);
