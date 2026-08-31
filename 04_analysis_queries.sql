/*
    04_analysis_queries.sql
    ------------------------
    Analytical queries over the normalized schema. Run after 03_load_data.sql.
*/

-- =====================================================================
-- Q1. Day-over-day price change per product, per city (window function: LAG)
-- =====================================================================
SELECT
    g.geography_label,
    pr.product_name,
    po.observed_date,
    po.normalized_price_amount,
    LAG(po.normalized_price_amount) OVER (
        PARTITION BY po.product_id, po.geography_id
        ORDER BY po.observed_date
    ) AS prev_day_price,
    po.normalized_price_amount
        - LAG(po.normalized_price_amount) OVER (
            PARTITION BY po.product_id, po.geography_id
            ORDER BY po.observed_date
          ) AS day_over_day_change,
    ROUND(
        (po.normalized_price_amount
            - LAG(po.normalized_price_amount) OVER (
                PARTITION BY po.product_id, po.geography_id
                ORDER BY po.observed_date
              ))
        / NULLIF(LAG(po.normalized_price_amount) OVER (
                PARTITION BY po.product_id, po.geography_id
                ORDER BY po.observed_date
          ), 0) * 100, 2
    ) AS day_over_day_pct_change
FROM dbo.PriceObservation po
JOIN dbo.Product pr   ON pr.product_id = po.product_id
JOIN dbo.Geography g  ON g.geography_id = po.geography_id
ORDER BY pr.product_name, g.geography_label, po.observed_date;
GO

-- =====================================================================
-- Q2. Cumulative inflation by city over the full observation window
--     (first observed day's avg price vs. last observed day's avg price),
--     ranked from highest inflation to biggest price drop.
-- =====================================================================
WITH DailyCityAvg AS (
    SELECT
        geography_id,
        observed_date,
        AVG(normalized_price_amount) AS avg_price
    FROM dbo.PriceObservation
    GROUP BY geography_id, observed_date
),
FirstLast AS (
    SELECT
        geography_id,
        MIN(observed_date) OVER (PARTITION BY geography_id) AS first_date,
        MAX(observed_date) OVER (PARTITION BY geography_id) AS last_date,
        observed_date,
        avg_price
    FROM DailyCityAvg
)
SELECT
    g.geography_label,
    fl_first.avg_price AS first_day_avg_price,
    fl_last.avg_price  AS last_day_avg_price,
    ROUND((fl_last.avg_price - fl_first.avg_price) / fl_first.avg_price * 100, 1) AS pct_change,
    RANK() OVER (
        ORDER BY (fl_last.avg_price - fl_first.avg_price) / fl_first.avg_price DESC
    ) AS inflation_rank
FROM FirstLast fl_first
JOIN FirstLast fl_last
    ON fl_first.geography_id = fl_last.geography_id
    AND fl_first.observed_date = fl_first.first_date
    AND fl_last.observed_date = fl_last.last_date
JOIN dbo.Geography g ON g.geography_id = fl_first.geography_id
ORDER BY inflation_rank;
GO

-- =====================================================================
-- Q3. Product price volatility (standard deviation of normalized price
--     across all cities/days), most volatile first.
-- =====================================================================
SELECT
    pr.product_name,
    ROUND(AVG(po.normalized_price_amount), 2) AS avg_price,
    ROUND(STDEV(po.normalized_price_amount), 2) AS price_stdev,
    COUNT(*) AS num_observations
FROM dbo.PriceObservation po
JOIN dbo.Product pr ON pr.product_id = po.product_id
GROUP BY pr.product_name
HAVING COUNT(*) > 1
ORDER BY price_stdev DESC;
GO

-- =====================================================================
-- Q4. Cheapest normalized price, per city per day (window function: RANK)
--     — a "where's the best deal today" basket query.
-- =====================================================================
WITH RankedPrices AS (
    SELECT
        g.geography_label,
        po.observed_date,
        pr.product_name,
        po.normalized_price_amount,
        RANK() OVER (
            PARTITION BY po.geography_id, po.observed_date
            ORDER BY po.normalized_price_amount ASC
        ) AS price_rank
    FROM dbo.PriceObservation po
    JOIN dbo.Product pr  ON pr.product_id = po.product_id
    JOIN dbo.Geography g ON g.geography_id = po.geography_id
)
SELECT geography_label, observed_date, product_name, normalized_price_amount
FROM RankedPrices
WHERE price_rank = 1
ORDER BY geography_label, observed_date;
GO

-- =====================================================================
-- Q5. Same-day, same-city, same-product price anomalies — flags rows where
--     the normalized price is more than 1.4x the median for that
--     product/day/city combo (useful for catching data entry errors or
--     genuinely mixed listings from different retailers under one name).
--     Threshold picked from this dataset's actual spread: the widest gap
--     observed is ~1.52x median, so 1.4x surfaces the real cases without
--     drowning in noise.
-- =====================================================================
WITH Medians AS (
    SELECT
        product_id,
        geography_id,
        observed_date,
        normalized_price_amount,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY normalized_price_amount)
            OVER (PARTITION BY product_id, geography_id, observed_date) AS median_price
    FROM dbo.PriceObservation
)
SELECT
    pr.product_name,
    g.geography_label,
    m.observed_date,
    m.normalized_price_amount,
    m.median_price,
    ROUND(m.normalized_price_amount / NULLIF(m.median_price, 0), 2) AS ratio_to_median
FROM Medians m
JOIN dbo.Product pr  ON pr.product_id = m.product_id
JOIN dbo.Geography g ON g.geography_id = m.geography_id
WHERE m.normalized_price_amount > 1.4 * m.median_price
ORDER BY ratio_to_median DESC;
GO
