-- ====================================================================
-- PLATFORM ARCHITECTURE: RAW LAYER (DATA STAGING DDL)
-- Objective: Establish database, isolated schemas, and staging DDL
-- for raw pharmaceutical shipment logs and hub weather API extracts.
-- Engine: Snowflake
-- ====================================================================

-- 1. Initialize Enterprise Database & Isolation Schemas
CREATE OR REPLACE DATABASE PHARMA_LOGISTICS;
CREATE OR REPLACE SCHEMA PHARMA_LOGISTICS.RAW;
CREATE OR REPLACE SCHEMA PHARMA_LOGISTICS.ANALYTICS;

-- 2. Staging DDL: Raw ERP Shipment Telemetry
CREATE OR REPLACE TABLE PHARMA_LOGISTICS.RAW.RAW_SHIPMENTS (
    Shipment_ID     VARCHAR,
    Product         VARCHAR,
    Origin          VARCHAR,
    Destination     VARCHAR,
    Carrier         VARCHAR,
    Spoiled_Flag    INT,
    Departure_Time  VARCHAR,
    Arrival_Time    VARCHAR
);

-- 3. Staging DDL: Raw Open-Meteo Hub Weather Telemetry
CREATE OR REPLACE TABLE PHARMA_LOGISTICS.RAW.RAW_WEATHER (
    Hub_City    VARCHAR,
    Date        VARCHAR,
    Max_Temp_C  FLOAT
);