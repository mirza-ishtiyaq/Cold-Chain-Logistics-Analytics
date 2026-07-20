-- Create our project database and the isolation schemas
CREATE OR REPLACE DATABASE PHARMA_LOGISTICS;
CREATE OR REPLACE SCHEMA PHARMA_LOGISTICS.RAW;
CREATE OR REPLACE SCHEMA PHARMA_LOGISTICS.ANALYTICS;

-- Create the structure for our raw shipping data
CREATE OR REPLACE TABLE PHARMA_LOGISTICS.RAW.RAW_SHIPMENTS (
    Shipment_ID VARCHAR,
    Product VARCHAR,
    Origin VARCHAR,
    Destination VARCHAR,
    Carrier VARCHAR,
    Spoiled_Flag INT,
    Departure_Time VARCHAR,
    Arrival_Time VARCHAR
);

-- Create the structure for our raw weather data
CREATE OR REPLACE TABLE PHARMA_LOGISTICS.RAW.RAW_WEATHER (
    Hub_City VARCHAR,
    Date VARCHAR,
    Max_Temp_C FLOAT
);PHARMA_LOGISTICS.RAW.RAW_SHIPMENTS