/*
    03_load_data.sql
    -----------------
    Moves data from the flat staging table into the normalized schema.
    CREATE TABLE only defines structure — it never moves data on its own,
    so every insert below is explicit.

    Run this AFTER 01_staging_table.sql (and loading the CSV into it) and
    AFTER 02_schema.sql.
*/

-- 1. Geography: dedupe staging down to one row per unique postal code
INSERT INTO dbo.Geography (geography_id, geography_label, geography_type)
SELECT DISTINCT geography_id, geography_label, geography_type
FROM dbo.Lettuce_Staging;
GO

-- 2. Product: dedupe down to one row per unique product name + its quantity info.
--    REPLACE(..., ',', '.') guards against a comma decimal separator sneaking in
--    from a non-US locale; on a period-decimal system it's a harmless no-op.
INSERT INTO dbo.Product (product_name, quantity_value, quantity_unit, quantity_name,
                          normalized_quantity_value, normalized_quantity_unit)
SELECT DISTINCT
    product_name,
    CAST(REPLACE(quantity_value, ',', '.') AS DECIMAL(10,2)),
    quantity_unit,
    quantity_name,
    CAST(REPLACE(normalized_quantity_value, ',', '.') AS DECIMAL(10,2)),
    normalized_quantity_unit
FROM dbo.Lettuce_Staging;
GO

-- 3. PriceObservation: one row per original staging row, resolved to the new
--    surrogate product_id via a join on product_name.
INSERT INTO dbo.PriceObservation (product_id, geography_id, observed_date,
                                   price_amount, normalized_price_amount, currency_code)
SELECT
    p.product_id,
    s.geography_id,
    s.observed_date,
    CAST(REPLACE(s.price_amount, ',', '.') AS DECIMAL(10,2)),
    CAST(REPLACE(s.normalized_price_amount, ',', '.') AS DECIMAL(10,2)),
    s.currency_code
FROM dbo.Lettuce_Staging s
JOIN dbo.Product p ON p.product_name = s.product_name;
GO

-- 4. Validation: row counts should line up with what's expected of this dataset
SELECT COUNT(*) AS staging_rows      FROM dbo.Lettuce_Staging;    -- expect 6651
SELECT COUNT(*) AS fact_rows         FROM dbo.PriceObservation;    -- should match staging_rows
SELECT COUNT(*) AS geography_count   FROM dbo.Geography;            -- expect 12
SELECT COUNT(*) AS product_count     FROM dbo.Product;               -- expect 37
GO
