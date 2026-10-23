/*
Project: COVID-19 Data Exploration Using PostgreSQL
Tables: covid_deaths, covid_vaccination
Dataset period verified by project notes: 2020-01-01 to 2021-04-30

Important interpretation notes:
1. This dataset contains reported cases, deaths, and vaccination records, not all infections.
2. The global case/death totals below sum daily new counts; do not sum cumulative total_cases/total_deaths across dates.
3. The vaccination running total represents reported doses, not unique people vaccinated.
4. Run the duplicate checks before relying on the location/date join and rolling totals.
*/

-- 1. Explore records that have a continent value
SELECT *
FROM covid_deaths
WHERE continent IS NOT NULL
ORDER BY location, date;

-- 2. Select core columns for analysis
SELECT
    location,
    date,
    total_cases,
    new_cases,
    total_deaths,
    population
FROM covid_deaths
WHERE continent IS NOT NULL
ORDER BY location, date;

-- 3. Total reported cases versus total reported deaths for the United States
-- The ILIKE filter matches locations containing "states"; keep the continent filter
-- so aggregate rows such as global/continent summaries are excluded.
SELECT
    location,
    date,
    total_cases,
    total_deaths,
    ROUND(
        total_deaths::numeric / NULLIF(total_cases::numeric, 0) * 100,
        2
    ) AS reported_case_fatality_percentage
FROM covid_deaths
WHERE location ILIKE '%states%'
  AND continent IS NOT NULL
ORDER BY location, date;

-- 4. Reported cases as a share of population over time
SELECT
    location,
    date,
    population,
    total_cases,
    ROUND(
        total_cases::numeric / NULLIF(population::numeric, 0) * 100,
        2
    ) AS reported_cases_as_percent_of_population
FROM covid_deaths
WHERE continent IS NOT NULL
ORDER BY location, date;

-- 5. Five locations with the highest reported infection rate in the dataset
-- Uses the maximum reported total_cases/population ratio observed for each location.
SELECT
    location,
    population,
    MAX(total_cases::numeric) AS highest_reported_case_count,
    ROUND(
        MAX(total_cases::numeric / NULLIF(population::numeric, 0)) * 100,
        2
    ) AS highest_reported_cases_percent_of_population
FROM covid_deaths
WHERE continent IS NOT NULL
  AND population IS NOT NULL
GROUP BY location, population
ORDER BY highest_reported_cases_percent_of_population DESC NULLS LAST
LIMIT 5;

-- 6. Five locations with the highest reported cumulative death counts
SELECT
    location,
    MAX(total_deaths::numeric) AS highest_reported_death_count
FROM covid_deaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY highest_reported_death_count DESC NULLS LAST
LIMIT 5;

-- 7. Latest available reported death count per location, summed by continent
-- Correct approach: MAX(total_deaths) grouped by continent would return only the
-- largest single location value in each continent, not a continent-wide sum.
WITH latest_deaths AS (
    SELECT DISTINCT ON (location)
        continent,
        location,
        total_deaths::numeric AS total_deaths
    FROM covid_deaths
    WHERE continent IS NOT NULL
      AND total_deaths IS NOT NULL
    ORDER BY location, date DESC
)
SELECT
    continent,
    SUM(total_deaths) AS summed_latest_reported_deaths
FROM latest_deaths
GROUP BY continent
ORDER BY summed_latest_reported_deaths DESC;

-- 8. Global reported cases, deaths, and case-fatality percentage
-- Sum daily new counts, not cumulative totals, to avoid double counting.
SELECT
    SUM(new_cases::numeric) AS total_reported_cases,
    SUM(new_deaths::numeric) AS total_reported_deaths,
    ROUND(
        SUM(new_deaths::numeric)
        / NULLIF(SUM(new_cases::numeric), 0) * 100,
        2
    ) AS reported_case_fatality_percentage
FROM covid_deaths
WHERE continent IS NOT NULL;

-- 9. Rolling reported vaccination doses by location and date
-- Precondition: the duplicate checks in section 13 should return no rows.
SELECT
    dea.continent,
    dea.location,
    dea.date,
    dea.population,
    vac.new_vaccinations,
    SUM(COALESCE(vac.new_vaccinations::numeric, 0)) OVER (
        PARTITION BY dea.location
        ORDER BY dea.date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS rolling_reported_vaccination_doses
FROM covid_deaths AS dea
JOIN covid_vaccination AS vac
  ON dea.location = vac.location
 AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
ORDER BY dea.location, dea.date;

-- 10. Rolling doses per 100 people using a CTE
-- This is a dose-based measure, not the percentage of unique people vaccinated.
WITH vaccination_progress AS (
    SELECT
        dea.continent,
        dea.location,
        dea.date,
        dea.population,
        vac.new_vaccinations,
        SUM(COALESCE(vac.new_vaccinations::numeric, 0)) OVER (
            PARTITION BY dea.location
            ORDER BY dea.date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS rolling_reported_vaccination_doses
    FROM covid_deaths AS dea
    JOIN covid_vaccination AS vac
      ON dea.location = vac.location
     AND dea.date = vac.date
    WHERE dea.continent IS NOT NULL
)
SELECT
    continent,
    location,
    date,
    population,
    new_vaccinations,
    rolling_reported_vaccination_doses,
    ROUND(
        rolling_reported_vaccination_doses
        / NULLIF(population::numeric, 0) * 100,
        2
    ) AS reported_doses_per_100_people
FROM vaccination_progress
ORDER BY location, date;

-- 11. Temporary table for reuse during the current PostgreSQL session
DROP TABLE IF EXISTS percent_population_vaccinated_temp;

CREATE TEMP TABLE percent_population_vaccinated_temp AS
SELECT
    dea.continent,
    dea.location,
    dea.date,
    dea.population,
    vac.new_vaccinations,
    SUM(COALESCE(vac.new_vaccinations::numeric, 0)) OVER (
        PARTITION BY dea.location
        ORDER BY dea.date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS rolling_reported_vaccination_doses
FROM covid_deaths AS dea
JOIN covid_vaccination AS vac
  ON dea.location = vac.location
 AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;

SELECT
    continent,
    location,
    date,
    population,
    new_vaccinations,
    rolling_reported_vaccination_doses,
    ROUND(
        rolling_reported_vaccination_doses
        / NULLIF(population::numeric, 0) * 100,
        2
    ) AS reported_doses_per_100_people
FROM percent_population_vaccinated_temp
ORDER BY location, date;

-- 12. Reusable view for visualization tools
-- The view exposes the rolling dose count; the final query calculates doses per 100.
CREATE OR REPLACE VIEW rolling_vaccination_progress AS
SELECT
    dea.continent,
    dea.location,
    dea.date,
    dea.population,
    vac.new_vaccinations,
    SUM(COALESCE(vac.new_vaccinations::numeric, 0)) OVER (
        PARTITION BY dea.location
        ORDER BY dea.date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS rolling_reported_vaccination_doses
FROM covid_deaths AS dea
JOIN covid_vaccination AS vac
  ON dea.location = vac.location
 AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;

SELECT
    continent,
    location,
    date,
    population,
    new_vaccinations,
    rolling_reported_vaccination_doses,
    ROUND(
        rolling_reported_vaccination_doses
        / NULLIF(population::numeric, 0) * 100,
        2
    ) AS reported_doses_per_100_people
FROM rolling_vaccination_progress
ORDER BY location, date;

-- 13. Data validation checks
-- 13A. Check table columns and data types
SELECT
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('covid_deaths', 'covid_vaccination')
ORDER BY table_name, ordinal_position;

-- 13B. Check duplicate location/date rows in deaths data
-- Expected: zero rows. If rows are returned, investigate before joining.
SELECT location, date, COUNT(*) AS record_count
FROM covid_deaths
GROUP BY location, date
HAVING COUNT(*) > 1
ORDER BY location, date;

-- 13C. Check duplicate location/date rows in vaccination data
-- Expected: zero rows. If rows are returned, investigate before joining.
SELECT location, date, COUNT(*) AS record_count
FROM covid_vaccination
GROUP BY location, date
HAVING COUNT(*) > 1
ORDER BY location, date;

-- 13D. Validate join coverage and detect rows without a vaccination match
SELECT
    COUNT(*) AS deaths_rows_with_continent,
    COUNT(vac.location) AS matching_location_date_rows,
    COUNT(*) - COUNT(vac.location) AS deaths_rows_without_vaccination_match
FROM covid_deaths AS dea
LEFT JOIN covid_vaccination AS vac
  ON dea.location = vac.location
 AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;

-- 13E. Inspect relevant column data types
SELECT
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('covid_deaths', 'covid_vaccination')
  AND column_name IN (
      'location', 'date', 'population',
      'total_cases', 'new_cases', 'total_deaths',
      'new_deaths', 'new_vaccinations'
  )
ORDER BY table_name, ordinal_position;
