1. Which geopolitical zone has the highest average food prices across all items and all 19 months?


SELECT zone, ROUND(AVG(price), 2) AS avg_price
FROM (
    SELECT north_central AS price, 'North Central' AS zone FROM food_prices
    UNION ALL
    SELECT north_east, 'North East' FROM food_prices
    UNION ALL
    SELECT north_west, 'North West' FROM food_prices
    UNION ALL
    SELECT south_east, 'South East' FROM food_prices
    UNION ALL
    SELECT south_south, 'South South' FROM food_prices
    UNION ALL
    SELECT south_west, 'South West' FROM food_prices
) AS unpivoted
GROUP BY zone
ORDER BY avg_price DESC
LIMIT 1;

2. What is the cheapest food item on average across all six zones?

WITH item_zone_avg AS (
    SELECT 
        food_item,
        ROUND(AVG(north_central), 2) AS north_central,
        ROUND(AVG(north_east), 2) AS north_east,
        ROUND(AVG(north_west), 2) AS north_west,
        ROUND(AVG(south_east), 2) AS south_east,
        ROUND(AVG(south_south), 2) AS south_south,
        ROUND(AVG(south_west), 2) AS south_west
    FROM food_prices
    GROUP BY food_item
),
unpivoted AS (
    SELECT food_item, 'North Central' AS zone, north_central AS avg_price FROM item_zone_avg
    UNION ALL
    SELECT food_item, 'North East', north_east FROM item_zone_avg
    UNION ALL
    SELECT food_item, 'North West', north_west FROM item_zone_avg
    UNION ALL
    SELECT food_item, 'South East', south_east FROM item_zone_avg
    UNION ALL
    SELECT food_item, 'South South', south_south FROM item_zone_avg
    UNION ALL
    SELECT food_item, 'South West', south_west FROM item_zone_avg
),
ranked AS (
    SELECT 
        zone,
        food_item,
        avg_price,
        ROW_NUMBER() OVER (PARTITION BY zone ORDER BY avg_price ASC) AS rn
    FROM unpivoted
)
SELECT 
    zone,
    food_item AS cheapest_food_item,
    avg_price
FROM ranked
WHERE rn = 1
ORDER BY zone;


3. What is the most expensive food item on average across all six zones?

WITH item_zone_avg AS (
    SELECT 
        food_item,
        AVG(north_central) AS north_central,
        AVG(north_east) AS north_east,
        AVG(north_west) AS north_west,
        AVG(south_east) AS south_east,
        AVG(south_south) AS south_south,
        AVG(south_west) AS south_west
    FROM food_prices
    GROUP BY food_item
),
unpivoted AS (
    SELECT food_item, 'North Central' AS zone, north_central AS avg_price FROM item_zone_avg
    UNION ALL
    SELECT food_item, 'North East', north_east FROM item_zone_avg
    UNION ALL
    SELECT food_item, 'North West', north_west FROM item_zone_avg
    UNION ALL
    SELECT food_item, 'South East', south_east FROM item_zone_avg
    UNION ALL
    SELECT food_item, 'South South', south_south FROM item_zone_avg
    UNION ALL
    SELECT food_item, 'South West', south_west FROM item_zone_avg
),
ranked AS (
    SELECT 
        zone,
        food_item,
        ROUND(avg_price, 2) AS avg_price,
        ROW_NUMBER() OVER (PARTITION BY zone ORDER BY avg_price DESC) AS rn
    FROM unpivoted
)
SELECT 
    zone,
    food_item AS most_expensive_food_item,
    avg_price
FROM ranked
WHERE rn = 1
ORDER BY zone;

4. What was the total average food price across all zones in November 2024 compared to May 2026? Has food generally gotten more expensive?

SELECT
    date,
    ROUND((
        AVG(north_central) +
        AVG(north_east) +
        AVG(north_west) +
        AVG(south_east) +
        AVG(south_south) +
        AVG(south_west)
    ) / 6, 2) AS national_avg
FROM food_prices
WHERE date IN ('2024-11-01', '2026-05-01')
GROUP BY date
ORDER BY date;

5. Which geopolitical zone consistently has the lowest average food prices and by how much does it differ from the most expensive zone?

WITH zone_avgs AS (
    SELECT 'North Central' AS zone, AVG(north_central) AS avg_price FROM food_prices
    UNION ALL
    SELECT 'North East', AVG(north_east) FROM food_prices
    UNION ALL
    SELECT 'North West', AVG(north_west) FROM food_prices
    UNION ALL
    SELECT 'South East', AVG(south_east) FROM food_prices
    UNION ALL
    SELECT 'South South', AVG(south_south) FROM food_prices
    UNION ALL
    SELECT 'South West', AVG(south_west) FROM food_prices
)
SELECT
    MIN(CASE WHEN avg_price = min_price THEN zone END) AS cheapest_zone,
    ROUND(min_price, 2) AS lowest_avg_price,
    ROUND(max_price, 2) AS highest_avg_price,
    ROUND(max_price - min_price, 2) AS price_gap
FROM (
    SELECT
        zone,
        avg_price,
        MIN(avg_price) OVER () AS min_price,
        MAX(avg_price) OVER () AS max_price
    FROM zone_avgs
) t
WHERE avg_price = min_price;

6. Which geopolitical zone is experiencing the fastest rise in food prices over the 19 months and is on track to become the most expensive zone to live in?


The below query shows:

starting price
ending price
absolute increase
percentage growth
current rank by ending price.

WITH zone_monthly AS (
    SELECT date, 'North Central' AS zone, AVG(north_central) AS avg_price FROM food_prices GROUP BY date
    UNION ALL
    SELECT date, 'North East', AVG(north_east) FROM food_prices GROUP BY date
    UNION ALL
    SELECT date, 'North West', AVG(north_west) FROM food_prices GROUP BY date
    UNION ALL
    SELECT date, 'South East', AVG(south_east) FROM food_prices GROUP BY date
    UNION ALL
    SELECT date, 'South South', AVG(south_south) FROM food_prices GROUP BY date
    UNION ALL
    SELECT date, 'South West', AVG(south_west) FROM food_prices GROUP BY date
),
ranked_dates AS (
    SELECT
        zone,
        date,
        avg_price,
        ROW_NUMBER() OVER (PARTITION BY zone ORDER BY date) AS rn_start,
        ROW_NUMBER() OVER (PARTITION BY zone ORDER BY date DESC) AS rn_end
    FROM zone_monthly
),
zone_growth AS (
    SELECT
        zone,
        MAX(CASE WHEN rn_start = 1 THEN avg_price END) AS starting_price,
        MAX(CASE WHEN rn_end = 1 THEN avg_price END) AS ending_price
    FROM ranked_dates
    GROUP BY zone
)
SELECT
    zone,
    ROUND(starting_price, 2) AS starting_price,
    ROUND(ending_price, 2) AS ending_price,
    ROUND(ending_price - starting_price, 2) AS price_increase,
    ROUND(((ending_price - starting_price) / starting_price) * 100, 2) AS growth_rate_pct,
    RANK() OVER (ORDER BY ending_price DESC) AS current_price_rank
FROM zone_growth
ORDER BY growth_rate_pct DESC;

7. How fast is the price gap between the most expensive and cheapest zones widening month by month from November 2024 to May 2026?

Keeps the monthly gap
Adds the month-to-month widening or narrowing
Directly answers whether inequality in food prices is increasing, stable, or shrinking

This is how to interpret the results you see:
price_gap: difference between the most expensive and cheapest zones in that month
gap_change_from_previous_month:
positive = gap widened
negative = gap narrowed
zero = no change

WITH zone_monthly AS (
    SELECT date, 'North Central' AS zone, AVG(north_central) AS avg_price FROM food_prices GROUP BY date
    UNION ALL
    SELECT date, 'North East', AVG(north_east) FROM food_prices GROUP BY date
    UNION ALL
    SELECT date, 'North West', AVG(north_west) FROM food_prices GROUP BY date
    UNION ALL
    SELECT date, 'South East', AVG(south_east) FROM food_prices GROUP BY date
    UNION ALL
    SELECT date, 'South South', AVG(south_south) FROM food_prices GROUP BY date
    UNION ALL
    SELECT date, 'South West', AVG(south_west) FROM food_prices GROUP BY date
),
monthly_gap AS (
    SELECT
        date,
        MAX(avg_price) AS most_expensive_zone_price,
        MIN(avg_price) AS cheapest_zone_price,
        MAX(avg_price) - MIN(avg_price) AS price_gap
    FROM zone_monthly
    GROUP BY date
)
SELECT
    date,
    ROUND(most_expensive_zone_price, 2) AS most_expensive_zone_price,
    ROUND(cheapest_zone_price, 2) AS cheapest_zone_price,
    ROUND(price_gap, 2) AS price_gap,
    ROUND(
        price_gap - LAG(price_gap) OVER (ORDER BY date),
        2
    ) AS gap_change_from_previous_month
FROM monthly_gap
ORDER BY date ASC;


8. Which geopolitical zone experiences the most unpredictable food prices with the highest month to month fluctuations?


WITH zone_monthly AS (
    SELECT date, 'North Central' AS zone, AVG(north_central) AS avg_price FROM food_prices GROUP BY date
    UNION ALL
    SELECT date, 'North East', AVG(north_east) FROM food_prices GROUP BY date
    UNION ALL
    SELECT date, 'North West', AVG(north_west) FROM food_prices GROUP BY date
    UNION ALL
    SELECT date, 'South East', AVG(south_east) FROM food_prices GROUP BY date
    UNION ALL
    SELECT date, 'South South', AVG(south_south) FROM food_prices GROUP BY date
    UNION ALL
    SELECT date, 'South West', AVG(south_west) FROM food_prices GROUP BY date
),
monthly_changes AS (
    SELECT
        zone,
        date,
        avg_price,
        avg_price - LAG(avg_price) OVER (PARTITION BY zone ORDER BY date) AS mom_change
    FROM zone_monthly
)
SELECT
    zone,
    ROUND(STDDEV(mom_change), 2) AS fluctuation_volatility,
    ROUND(AVG(ABS(mom_change)), 2) AS avg_monthly_change,
    ROUND(MAX(ABS(mom_change)), 2) AS largest_monthly_swing
FROM monthly_changes
WHERE mom_change IS NOT NULL
GROUP BY zone
ORDER BY fluctuation_volatility DESC
LIMIT 1;


9. Which zone and food item combination shows the highest prices AND the fastest growth rate, making it the most urgent target for government food intervention?


WITH item_zone_monthly AS (
    SELECT date, food_item, 'North Central' AS zone, AVG(north_central) AS avg_price
    FROM food_prices
    GROUP BY date, food_item

    UNION ALL

    SELECT date, food_item, 'North East' AS zone, AVG(north_east) AS avg_price
    FROM food_prices
    GROUP BY date, food_item

    UNION ALL

    SELECT date, food_item, 'North West' AS zone, AVG(north_west) AS avg_price
    FROM food_prices
    GROUP BY date, food_item

    UNION ALL

    SELECT date, food_item, 'South East' AS zone, AVG(south_east) AS avg_price
    FROM food_prices
    GROUP BY date, food_item

    UNION ALL

    SELECT date, food_item, 'South South' AS zone, AVG(south_south) AS avg_price
    FROM food_prices
    GROUP BY date, food_item

    UNION ALL

    SELECT date, food_item, 'South West' AS zone, AVG(south_west) AS avg_price
    FROM food_prices
    GROUP BY date, food_item
),
ranked_dates AS (
    SELECT
        food_item,
        zone,
        date,
        avg_price,
        ROW_NUMBER() OVER (PARTITION BY food_item, zone ORDER BY date ASC) AS rn_start,
        ROW_NUMBER() OVER (PARTITION BY food_item, zone ORDER BY date DESC) AS rn_end
    FROM item_zone_monthly
),
item_zone_growth AS (
    SELECT
        food_item,
        zone,
        MAX(CASE WHEN rn_start = 1 THEN avg_price END) AS starting_price,
        MAX(CASE WHEN rn_end = 1 THEN avg_price END) AS ending_price
    FROM ranked_dates
    GROUP BY food_item, zone
),
scored AS (
    SELECT
        food_item,
        zone,
        starting_price,
        ending_price,
        ending_price - starting_price AS price_increase,
        ((ending_price - starting_price) / NULLIF(starting_price, 0)) * 100 AS growth_rate_pct
    FROM item_zone_growth
)
SELECT
    zone,
    food_item,
    ROUND(starting_price, 2) AS starting_price,
    ROUND(ending_price, 2) AS ending_price,
    ROUND(price_increase, 2) AS price_increase,
    ROUND(growth_rate_pct, 2) AS growth_rate_pct
FROM scored
ORDER BY ending_price DESC, growth_rate_pct DESC
LIMIT 10;



