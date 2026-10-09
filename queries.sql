-- SQL-анализ рынка видеоигр для интернет-магазина «Стримчик»

-- 1.1. Общее количество записей
SELECT COUNT(*) AS total_rows
FROM games;


-- 1.2. Проверка дубликатов по (name, platform, year_of_release)
SELECT name, platform, year_of_release, COUNT(*) AS cnt
FROM games
GROUP BY name, platform, year_of_release
HAVING COUNT(*) > 1
ORDER BY cnt DESC;


-- 1.3. Доля пропусков в ключевых полях
SELECT
    ROUND(100.0 * SUM(CASE WHEN user_score   IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS user_score_null_pct,
    ROUND(100.0 * SUM(CASE WHEN critic_score IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS critic_score_null_pct,
    ROUND(100.0 * SUM(CASE WHEN year_of_release IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS year_null_pct
FROM games;


-- 1.4. Диапазон годов выпуска
SELECT
    MIN(year_of_release) AS min_year,
    MAX(year_of_release) AS max_year,
    COUNT(DISTINCT year_of_release) AS distinct_years
FROM games;


-- 2.1. Количество выпущенных игр по годам
SELECT year_of_release, COUNT(*) AS games_released
FROM games
WHERE year_of_release IS NOT NULL
GROUP BY year_of_release
ORDER BY year_of_release;


-- 2.2. Пик выпуска игр (топ-5 лет по количеству релизов)
SELECT year_of_release, COUNT(*) AS games_released
FROM games
WHERE year_of_release IS NOT NULL
GROUP BY year_of_release
ORDER BY games_released DESC
LIMIT 5;


-- 3.1. Витрина: суммарные продажи по платформам за актуальный период (2013+)
DROP VIEW IF EXISTS v_platform_sales;
CREATE VIEW v_platform_sales AS
SELECT
    platform,
    SUM(na_sales)                     AS na_total,
    SUM(eu_sales)                     AS eu_total,
    SUM(jp_sales)                     AS jp_total,
    SUM(other_sales)                  AS other_total,
    SUM(na_sales + eu_sales + jp_sales + other_sales) AS global_total
FROM games
WHERE year_of_release >= 2013
GROUP BY platform;

-- Проверка витрины
SELECT * FROM v_platform_sales
ORDER BY global_total DESC
LIMIT 10;


-- 3.2. Витрина: продажи по жанрам и рейтингу ESRB
DROP VIEW IF EXISTS v_genre_rating_sales;
CREATE VIEW v_genre_rating_sales AS
SELECT
    genre,
    CASE
        WHEN rating IS NULL THEN 'unknown'
        ELSE rating
    END AS rating_clean,
    SUM(na_sales + eu_sales + jp_sales + other_sales) AS total_sales
FROM games
WHERE year_of_release >= 2013
GROUP BY genre, rating_clean;

-- Проверка витрины
SELECT * FROM v_genre_rating_sales
ORDER BY total_sales DESC
LIMIT 10;


-- 4.1. Топ-5 платформ в каждом регионе (NA, EU, JP)
-- Демонстрирует: CTE + RANK() OVER (PARTITION BY ...)
WITH ranked AS (
    SELECT
        platform,
        SUM(na_sales) AS na_sales,
        SUM(eu_sales) AS eu_sales,
        SUM(jp_sales) AS jp_sales
    FROM games
    WHERE year_of_release >= 2013
    GROUP BY platform
),
regional_top AS (
    SELECT 'NA' AS region, platform, na_sales AS sales,
           RANK() OVER (ORDER BY na_sales DESC) AS rnk
    FROM ranked
    UNION ALL
    SELECT 'EU', platform, eu_sales,
           RANK() OVER (ORDER BY eu_sales DESC)
    FROM ranked
    UNION ALL
    SELECT 'JP', platform, jp_sales,
           RANK() OVER (ORDER BY jp_sales DESC)
    FROM ranked
)
SELECT region, rnk, platform, sales
FROM regional_top
WHERE rnk <= 5
ORDER BY region, rnk;


-- 4.2. Топ-5 жанров в каждом регионе
WITH ranked AS (
    SELECT
        genre,
        SUM(na_sales) AS na_sales,
        SUM(eu_sales) AS eu_sales,
        SUM(jp_sales) AS jp_sales
    FROM games
    WHERE year_of_release >= 2013
    GROUP BY genre
),
regional_top AS (
    SELECT 'NA' AS region, genre, na_sales AS sales,
           RANK() OVER (ORDER BY na_sales DESC) AS rnk
    FROM ranked
    UNION ALL
    SELECT 'EU', genre, eu_sales,
           RANK() OVER (ORDER BY eu_sales DESC)
    FROM ranked
    UNION ALL
    SELECT 'JP', genre, jp_sales,
           RANK() OVER (ORDER BY jp_sales DESC)
    FROM ranked
)
SELECT region, rnk, genre, sales
FROM regional_top
WHERE rnk <= 5
ORDER BY region, rnk;


-- 5.1. Топ-10 игр по глобальным продажам
SELECT
    name,
    platform,
    year_of_release,
    genre,
    (na_sales + eu_sales + jp_sales + other_sales) AS global_sales
FROM games
ORDER BY global_sales DESC
LIMIT 10;


-- 5.2. Средние оценки критиков и пользователей по платформам
-- (включая сравнение XOne и PC)
SELECT
    platform,
    COUNT(*)                     AS games_with_scores,
    ROUND(AVG(critic_score), 2)  AS avg_critic,
    ROUND(AVG(user_score), 2)    AS avg_user
FROM games
WHERE year_of_release >= 2013
  AND user_score IS NOT NULL
  AND critic_score IS NOT NULL
GROUP BY platform
ORDER BY games_with_scores DESC;


-- 5.3. Сравнение средних оценок XOne и PC (для t-теста)
SELECT
    platform,
    COUNT(user_score)            AS n,
    ROUND(AVG(user_score), 4)    AS mean_user_score,
    ROUND(
        (SUM(user_score * user_score) - COUNT(user_score) * AVG(user_score) * AVG(user_score))
        / (COUNT(user_score) - 1)
    , 4)                         AS var_user_score
FROM games
WHERE year_of_release >= 2013
  AND user_score IS NOT NULL
  AND platform IN ('XOne', 'PC')
GROUP BY platform;


-- 5.4. Доля продаж каждой платформы от общего объёма (за 2013+)
WITH total AS (
    SELECT SUM(na_sales + eu_sales + jp_sales + other_sales) AS global_sum
    FROM games
    WHERE year_of_release >= 2013
)
SELECT
    platform,
    SUM(na_sales + eu_sales + jp_sales + other_sales) AS platform_sales,
    ROUND(
        100.0 * SUM(na_sales + eu_sales + jp_sales + other_sales) / (SELECT global_sum FROM total)
    , 2) AS pct_of_total
FROM games
WHERE year_of_release >= 2013
GROUP BY platform
ORDER BY platform_sales DESC;


-- 6.1. Доля продаж по рейтингу ESRB в каждом регионе (за 2013+)
SELECT
    CASE WHEN rating IS NULL THEN 'unknown' ELSE rating END AS rating_clean,
    ROUND(100.0 * SUM(na_sales) / (SELECT SUM(na_sales) FROM games WHERE year_of_release >= 2013), 2) AS na_pct,
    ROUND(100.0 * SUM(eu_sales) / (SELECT SUM(eu_sales) FROM games WHERE year_of_release >= 2013), 2) AS eu_pct,
    ROUND(100.0 * SUM(jp_sales) / (SELECT SUM(jp_sales) FROM games WHERE year_of_release >= 2013), 2) AS jp_pct
FROM games
WHERE year_of_release >= 2013
GROUP BY rating_clean
ORDER BY na_pct DESC;
