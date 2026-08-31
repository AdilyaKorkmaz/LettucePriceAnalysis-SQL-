/*
    02_schema.sql
    -------------
    Normalized target schema: two dimension tables (Geography, Product)
    and one fact table (PriceObservation), one row per price observation.

    series_id / series_title / canonical_url / currency_code are dropped
    as separate dimensions: every row in this dataset has the same value
    for each of them ('lettuce', 'Lettuce', <url>, 'USD'), so a dimension
    table would carry zero information. currency_code is kept as a column
    on the fact table with a default, in case a future load introduces a
    second currency.
*/

IF OBJECT_ID('dbo.PriceObservation', 'U') IS NOT NULL DROP TABLE dbo.PriceObservation;
IF OBJECT_ID('dbo.Product', 'U') IS NOT NULL DROP TABLE dbo.Product;
IF OBJECT_ID('dbo.Geography', 'U') IS NOT NULL DROP TABLE dbo.Geography;
GO

CREATE TABLE dbo.Geography (
    geography_id     VARCHAR(10)   NOT NULL PRIMARY KEY,   -- postal code, e.g. '11385'
    geography_label  VARCHAR(100)  NOT NULL,                -- 'New York, NY - Ridgewood/Glendale'
    geography_type   VARCHAR(20)   NOT NULL DEFAULT 'postal_code'
);
GO

CREATE TABLE dbo.Product (
    product_id                  INT IDENTITY(1,1) PRIMARY KEY,
    product_name                  VARCHAR(200)   NOT NULL UNIQUE,
    quantity_value                  DECIMAL(10,2)  NOT NULL,
    quantity_unit                    VARCHAR(20)    NOT NULL,
    quantity_name                     VARCHAR(30)    NOT NULL,
    normalized_quantity_value           DECIMAL(10,2)  NOT NULL,
    normalized_quantity_unit              VARCHAR(20)    NOT NULL
);
GO

CREATE TABLE dbo.PriceObservation (
    observation_id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    product_id                    INT            NOT NULL FOREIGN KEY REFERENCES dbo.Product(product_id),
    geography_id                    VARCHAR(10)    NOT NULL FOREIGN KEY REFERENCES dbo.Geography(geography_id),
    observed_date                     DATE           NOT NULL,
    price_amount                        DECIMAL(10,2)  NOT NULL,
    normalized_price_amount               DECIMAL(10,2)  NOT NULL,
    currency_code                           CHAR(3)        NOT NULL DEFAULT 'USD'
);
GO

-- Indexes to support the analytical queries in 04_analysis_queries.sql
CREATE INDEX IX_PriceObs_Product_Date ON dbo.PriceObservation(product_id, observed_date);
CREATE INDEX IX_PriceObs_Geo_Date ON dbo.PriceObservation(geography_id, observed_date);
GO
