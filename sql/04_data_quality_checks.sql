-- ====================================================================
-- PLATFORM ARCHITECTURE: DATA QUALITY & INTEGRITY CHECKS
-- Objective: Surface data integrity issues in the RAW / CLEAN layers
-- that silently distort the GOLD-layer financial model if left
-- unchecked -- duplicate shipment records and shipments that fail to
-- join to origin-hub weather telemetry.
-- Engine: Snowflake
-- ====================================================================

USE DATABASE PHARMA_LOGISTICS;
USE SCHEMA ANALYTICS;

-- 1. Duplicate Shipment_ID Detection
-- The raw ERP extract contains repeated Shipment_ID values where the
-- repeated rows do NOT agree on Product / Spoiled_Flag / Carrier --
-- i.e. these are conflicting records for the same shipment ID, not
-- harmless duplicate rows, and they double-count revenue-loss
-- exposure if left uncleaned in the GOLD layer.
CREATE OR REPLACE VIEW PHARMA_LOGISTICS.ANALYTICS.DQ_DUPLICATE_SHIPMENTS AS
SELECT
    Shipment_ID,
    COUNT(*)                           AS Record_Count,
    COUNT(DISTINCT Product)            AS Distinct_Product_Values,
    COUNT(DISTINCT Spoiled_Flag)       AS Distinct_Spoiled_Flag_Values,
    COUNT(DISTINCT Carrier)            AS Distinct_Carrier_Values
FROM PHARMA_LOGISTICS.RAW.RAW_SHIPMENTS
GROUP BY Shipment_ID
HAVING COUNT(*) > 1
ORDER BY Distinct_Spoiled_Flag_Values DESC, Distinct_Product_Values DESC;

-- Validated against the source CSV (data/raw/dirty_pharma_shipments.csv):
-- 124 duplicated Shipment_ID values (250 raw rows). Of those, 84 IDs
-- disagree on Product and 14 disagree on Spoiled_Flag between the
-- "duplicate" rows -- true data conflicts, not clean re-sends.
-- Recommended fix: apply a deterministic dedup rule (e.g. a
-- ROW_NUMBER() OVER (PARTITION BY Shipment_ID ORDER BY <load_ts> DESC)
-- QUALIFY = 1) in RAW before CLEAN_SHIPMENTS is built, once a
-- trustworthy load/ingest timestamp is available from the source ERP.

-- 2. Orphaned Shipment-to-Weather Join Coverage
-- BUSINESS_SPOILAGE_MODEL LEFT JOINs shipments to weather on
-- (Origin Hub, Departure Date). Quantify how much of the shipment
-- population actually has a matching weather record, since a low
-- match rate silently weakens any temperature-driven root-cause
-- finding built on top of that join.
CREATE OR REPLACE VIEW PHARMA_LOGISTICS.ANALYTICS.DQ_WEATHER_JOIN_COVERAGE AS
SELECT
    COUNT(*)                                          AS Total_Shipments,
    COUNT(w.Max_Temp_C)                               AS Shipments_With_Weather_Match,
    COUNT(*) - COUNT(w.Max_Temp_C)                    AS Orphaned_Shipments,
    ROUND(COUNT(w.Max_Temp_C) / COUNT(*) * 100, 2)    AS Match_Rate_Pct
FROM PHARMA_LOGISTICS.ANALYTICS.CLEAN_SHIPMENTS s
LEFT JOIN PHARMA_LOGISTICS.ANALYTICS.CLEAN_WEATHER w
    ON s.Clean_Origin = w.Clean_Hub_City
    AND TO_DATE(s.Standardized_Departure_Time) = w.Standardized_Date;

-- Validated against the source CSVs: only ~49% of shipments
-- (2,446 / 5,000) match a weather record. RAW_WEATHER only covers
-- 2025-01-01 through 2025-06-30, while RAW_SHIPMENTS departure dates
-- run through Jan-2026 -- so any temperature-based root-cause claim
-- in the GOLD layer is only backed by roughly half the shipment
-- population and should always be reported with that caveat until the
-- Open-Meteo pull is extended to cover the full shipment date range.
