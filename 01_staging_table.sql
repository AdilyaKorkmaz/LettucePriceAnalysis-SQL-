/*
    01_staging_table.sql
    ---------------------
    Creates the landing table for the raw flat file. This table intentionally
    mirrors the CSV column-for-column with NO primary key and NO foreign keys.

    Why keep quantity_value / price_amount / normalized_* as NVARCHAR instead of
    FLOAT or DECIMAL here?
    SQL Server's "Import Flat File" wizard parses numeric columns using the
    machine's regional (locale) settings. On any system where the decimal
    separator is a comma instead of a period, importing a period-decimal CSV
    straight into a FLOAT/DECIMAL column throws:
        "Input string was not in a correct format. (mscorlib)"
    Staging these columns as text sidesteps the issue entirely — the import
    step can't fail on locale, since text is text. Conversion happens
    explicitly and safely in 03_load_data.sql, where we control it.
*/

IF OBJECT_ID('dbo.Lettuce_Staging', 'U') IS NOT NULL
    DROP TABLE dbo.Lettuce_Staging;
GO

CREATE TABLE dbo.Lettuce_Staging (
    series_id                  NVARCHAR(50)   NULL,
    series_title                NVARCHAR(50)   NULL,
    canonical_url                 NVARCHAR(100)  NULL,
    geography_type                  NVARCHAR(50)   NULL,
    geography_id                      NVARCHAR(10)   NULL,
    geography_label                     NVARCHAR(50)   NULL,
    observed_date                         DATE           NULL,
    product_name                           NVARCHAR(100)  NULL,
    quantity_value                           NVARCHAR(50)   NULL,
    quantity_unit                             NVARCHAR(50)   NULL,
    quantity_name                               NVARCHAR(50)   NULL,
    price_amount                                  NVARCHAR(50)   NULL,
    currency_code                                   NVARCHAR(50)   NULL,
    normalized_price_amount                           NVARCHAR(50)   NULL,
    normalized_quantity_value                           NVARCHAR(50)   NULL,
    normalized_quantity_unit                              NVARCHAR(50)   NULL
);
GO

/*
    Load the data using ONE of:

    A) SSMS "Import Flat File" wizard (right-click the database ->
       Tasks -> Import Flat File), pointing it at:
         data/costinflation-lettuce-retail-prices-raw-2026-07-13-to-2026-08-10.csv
       and mapping into dbo.Lettuce_Staging with the types above
       (set every column to allow NULLs, no primary key).

    B) BULK INSERT from a query window (adjust the path to wherever
       the CSV lives on the machine running SQL Server):

    BULK INSERT dbo.Lettuce_Staging
    FROM 'C:\path\to\costinflation-lettuce-retail-prices-raw-2026-07-13-to-2026-08-10.csv'
    WITH (
        FIRSTROW = 2,
        FIELDTERMINATOR = ',',
        ROWTERMINATOR = '0x0a',
        TABLOCK,
        CODEPAGE = '65001'   -- UTF-8
    );
*/
