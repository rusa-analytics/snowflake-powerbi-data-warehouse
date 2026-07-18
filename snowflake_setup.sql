-- =====================================================================
-- RUSA Analytics | Critical Minerals Market Intelligence
-- Snowflake warehouse + schema build script
-- Commodities in scope: Lithium, Graphite, Manganese, Cobalt
-- =====================================================================

-- 1. WAREHOUSE, DATABASE, SCHEMA -------------------------------------
CREATE WAREHOUSE IF NOT EXISTS WH_MINERALS
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;

CREATE DATABASE IF NOT EXISTS CRITICAL_MINERALS;
USE DATABASE CRITICAL_MINERALS;

CREATE SCHEMA IF NOT EXISTS RAW;      -- landing zone, mirrors source CSV structure
CREATE SCHEMA IF NOT EXISTS CORE;     -- cleaned star schema
CREATE SCHEMA IF NOT EXISTS REPORTING; -- views consumed directly by Power BI

-- 2. FILE FORMAT + STAGE ----------------------------------------------
USE SCHEMA RAW;

CREATE OR REPLACE FILE FORMAT FF_CSV_STANDARD
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL')
    EMPTY_FIELD_AS_NULL = TRUE;

-- Internal stage; in production this would point at the client's
-- cloud storage (S3 / Azure Blob) via a STORAGE INTEGRATION instead.
CREATE OR REPLACE STAGE STG_MINERALS
    FILE_FORMAT = FF_CSV_STANDARD;

-- Upload with SnowSQL or the Snowsight "Load Data" UI, e.g.:
--   PUT file://fact_commodity_market.csv @STG_MINERALS AUTO_COMPRESS=TRUE;
--   PUT file://dim_commodity.csv        @STG_MINERALS AUTO_COMPRESS=TRUE;
--   PUT file://dim_geography.csv        @STG_MINERALS AUTO_COMPRESS=TRUE;

-- 3. RAW LANDING TABLES -------------------------------------------------
CREATE OR REPLACE TABLE RAW.FACT_COMMODITY_MARKET (
    market_date        DATE,
    commodity_id        VARCHAR(4),
    commodity_name       VARCHAR(50),
    unit             VARCHAR(30),
    country_iso        VARCHAR(4),
    country_name        VARCHAR(60),
    supplier_name       VARCHAR(100),
    price_usd          NUMBER(12,2),
    production_tonnes     NUMBER(12,1)
);

CREATE OR REPLACE TABLE RAW.DIM_COMMODITY (
    commodity_id    VARCHAR(4),
    commodity_name   VARCHAR(50),
    unit         VARCHAR(30)
);

CREATE OR REPLACE TABLE RAW.DIM_GEOGRAPHY (
    commodity_id     VARCHAR(4),
    country_iso      VARCHAR(4),
    country_name     VARCHAR(60),
    production_share  NUMBER(5,4)
);

COPY INTO RAW.FACT_COMMODITY_MARKET
    FROM @STG_MINERALS/fact_commodity_market.csv.gz
    FILE_FORMAT = FF_CSV_STANDARD
    ON_ERROR = 'ABORT_STATEMENT';

COPY INTO RAW.DIM_COMMODITY
    FROM @STG_MINERALS/dim_commodity.csv.gz
    FILE_FORMAT = FF_CSV_STANDARD;

COPY INTO RAW.DIM_GEOGRAPHY
    FROM @STG_MINERALS/dim_geography.csv.gz
    FILE_FORMAT = FF_CSV_STANDARD;

-- 4. CORE STAR SCHEMA ----------------------------------------------------
USE SCHEMA CORE;

CREATE OR REPLACE TABLE CORE.DIM_DATE AS
SELECT DISTINCT
    market_date                          AS date_key,
    YEAR(market_date)                    AS year,
    MONTH(market_date)                   AS month,
    TO_CHAR(market_date,'YYYY-MM')       AS year_month,
    QUARTER(market_date)                 AS quarter
FROM RAW.FACT_COMMODITY_MARKET;

CREATE OR REPLACE TABLE CORE.DIM_COMMODITY AS
SELECT * FROM RAW.DIM_COMMODITY;

CREATE OR REPLACE TABLE CORE.DIM_GEOGRAPHY AS
SELECT DISTINCT country_iso, country_name FROM RAW.DIM_GEOGRAPHY;

CREATE OR REPLACE TABLE CORE.DIM_SUPPLIER AS
SELECT
    ROW_NUMBER() OVER (ORDER BY supplier_name)  AS supplier_key,
    supplier_name,
    country_iso
FROM (SELECT DISTINCT supplier_name, country_iso FROM RAW.FACT_COMMODITY_MARKET);

CREATE OR REPLACE TABLE CORE.FACT_MARKET AS
SELECT
    f.market_date                AS date_key,
    f.commodity_id,
    f.country_iso,
    s.supplier_key,
    f.price_usd,
    f.production_tonnes
FROM RAW.FACT_COMMODITY_MARKET f
JOIN CORE.DIM_SUPPLIER s
    ON f.supplier_name = s.supplier_name AND f.country_iso = s.country_iso;

-- 5. REPORTING LAYER (what Power BI actually connects to) ---------------
-- A single flattened, business-friendly view avoids exposing surrogate
-- keys and join logic to the BI layer, and lets Power BI use DirectQuery
-- without pulling raw/staging tables into scope.
USE SCHEMA REPORTING;

CREATE OR REPLACE VIEW REPORTING.VW_MARKET_INTELLIGENCE AS
SELECT
    d.date_key,
    d.year,
    d.month,
    d.year_month,
    c.commodity_name,
    c.unit,
    g.country_name,
    sup.supplier_name,
    f.price_usd,
    f.production_tonnes
FROM CORE.FACT_MARKET f
JOIN CORE.DIM_DATE d       ON f.date_key = d.date_key
JOIN CORE.DIM_COMMODITY c  ON f.commodity_id = c.commodity_id
JOIN CORE.DIM_GEOGRAPHY g  ON f.country_iso = g.country_iso
JOIN CORE.DIM_SUPPLIER sup ON f.supplier_key = sup.supplier_key;

-- Pre-aggregated monthly price view: keeps the Power BI model light and
-- fast for the price-trend visual, which doesn't need supplier grain.
CREATE OR REPLACE VIEW REPORTING.VW_MONTHLY_PRICE_TREND AS
SELECT
    year_month,
    commodity_name,
    ROUND(AVG(price_usd), 2) AS avg_price_usd
FROM REPORTING.VW_MARKET_INTELLIGENCE
GROUP BY year_month, commodity_name;

-- Supply concentration view: powers an HHI-style concentration read,
-- a standard commodity-risk lens for procurement audiences.
CREATE OR REPLACE VIEW REPORTING.VW_SUPPLY_CONCENTRATION AS
SELECT
    commodity_name,
    country_name,
    year,
    SUM(production_tonnes) AS total_production_tonnes,
    ROUND(
        SUM(production_tonnes) / SUM(SUM(production_tonnes)) OVER (PARTITION BY commodity_name, year),
        4
    ) AS production_share
FROM REPORTING.VW_MARKET_INTELLIGENCE
GROUP BY commodity_name, country_name, year;

-- 6. LEAST-PRIVILEGE ROLE FOR POWER BI ------------------------------------
CREATE ROLE IF NOT EXISTS ROLE_POWERBI_READER;
GRANT USAGE ON WAREHOUSE WH_MINERALS TO ROLE ROLE_POWERBI_READER;
GRANT USAGE ON DATABASE CRITICAL_MINERALS TO ROLE ROLE_POWERBI_READER;
GRANT USAGE ON SCHEMA REPORTING TO ROLE ROLE_POWERBI_READER;
GRANT SELECT ON ALL VIEWS IN SCHEMA REPORTING TO ROLE ROLE_POWERBI_READER;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA REPORTING TO ROLE ROLE_POWERBI_READER;
-- Power BI's Snowflake connector authenticates as a service account
-- carrying only this role -- it never sees RAW or CORE schemas.
