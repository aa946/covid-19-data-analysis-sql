--Query 1: Explore the COVID deaths dataset
-- View all records where continent is available

SELECT *
FROM covid_deaths
WHERE continent IS NOT NULL
ORDER BY 3, 4;

---Query 2: Select the columns for analysis

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
---Step 3: Total Cases vs. Total Deaths
SELECT
    location,
    date,
    total_cases,
    total_deaths,
    (total_deaths::numeric / NULLIF(total_cases::numeric, 0))
        * 100 AS death_percentage
FROM covid_deaths
WHERE location ILIKE '%states%'
  AND continent IS NOT NULL
ORDER BY location, date;
--Step 4: Total Cases vs. Population
SELECT
    location,
    date,
    population,
    total_cases,
    (total_cases::numeric / NULLIF(population::numeric, 0))
        * 100 AS percent_population_infected
FROM covid_deaths
WHERE continent IS NOT NULL
ORDER BY location, date;
--Step 5: Countries with the Highest Infection Rate
SELECT
    location,
    population,
    MAX(total_cases::numeric) AS highest_infection_count,
    MAX(
        (total_cases::numeric / NULLIF(population::numeric, 0)) * 100
    ) AS percent_population_infected
FROM covid_deaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY percent_population_infected DESC NULLS LAST;
---Query 6: Countries with the highest reported death count
SELECT
    location,
    MAX(total_deaths::numeric) AS total_death_count
FROM covid_deaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY total_death_count DESC NULLS LAST;
---Query 7: Continents with the highest reported death count
SELECT
    continent,
    MAX(total_deaths::numeric) AS total_death_count
FROM covid_deaths
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY total_death_count DESC NULLS LAST;
--Calculate total deaths per continent correctly
--The problem is that MAX(total_deaths) within a 
--continent gives the highest location-level value, 
--not the sum of the latest death counts across all locations.

WITH latest_deaths AS (
    SELECT DISTINCT ON (location)
        continent,
        location,
        total_deaths
    FROM covid_deaths
    WHERE continent IS NOT NULL
      AND total_deaths IS NOT NULL
    ORDER BY location, date DESC
)
SELECT
    continent,
    SUM(total_deaths) AS total_continent_deaths
FROM latest_deaths
GROUP BY continent
ORDER BY total_continent_deaths DESC;
---Query 8: Global numbers
SELECT
    SUM(new_cases::numeric) AS total_cases,
    SUM(new_deaths::numeric) AS total_deaths,
    (SUM(new_deaths::numeric)
        / NULLIF(SUM(new_cases::numeric), 0)) * 100
        AS death_percentage
FROM covid_deaths
WHERE continent IS NOT NULL;
---2. Total population vs. vaccinations — JOIN and window function
---This section uses both tables:
---- covid_deaths — population and location information.
---- covid_vaccination — new vaccination records.
--Query 9: Calculate rolling vaccinations
--“How many vaccinations have been reported cumulatively in each location up to each date?”
SELECT
    dea.continent,
    dea.location,
    dea.date,
    dea.population,
    vac.new_vaccinations,
    SUM(COALESCE(vac.new_vaccinations::numeric, 0))
        OVER (
            PARTITION BY dea.location
            ORDER BY dea.date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS rolling_people_vaccinated
FROM covid_deaths AS dea
JOIN covid_vaccination AS vac
    ON dea.location = vac.location
   AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
ORDER BY dea.location, dea.date;
---Duplicate matches could inflate the rolling totals.
SELECT
    location,
    date,
    COUNT(*) AS record_count
FROM covid_vaccination
GROUP BY location, date
HAVING COUNT(*) > 1;

--Validate the vaccination percentage
---Your rolling-total query calculates cumulative reported
--new_vaccinations, but that does not necessarily equal 
--the number of unique people vaccinated.
--First, calculate the rolling total and percentage of population:
WITH vaccination_progress AS (
    SELECT
        dea.continent,
        dea.location,
        dea.date,
        dea.population,
        vac.new_vaccinations,
        SUM(COALESCE(vac.new_vaccinations::numeric, 0))
            OVER (
                PARTITION BY dea.location
                ORDER BY dea.date
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS rolling_vaccinations
    FROM covid_deaths AS dea
    JOIN covid_vaccination AS vac
        ON dea.location = vac.location
       AND dea.date = vac.date
    WHERE dea.continent IS NOT NULL
)
SELECT
    location,
    date,
    population,
    rolling_vaccinations,
    ROUND(
        rolling_vaccinations / NULLIF(population::numeric, 0) * 100,
        2
    ) AS vaccination_doses_per_100_people
FROM vaccination_progress
ORDER BY location, date;
---Query 10: Use a CTE to calculate vaccination percentage
WITH popvsvac AS (
    SELECT
        dea.continent,
        dea.location,
        dea.date,
        dea.population,
        vac.new_vaccinations,
        SUM(COALESCE(vac.new_vaccinations::numeric, 0))
            OVER (
                PARTITION BY dea.location
                ORDER BY dea.date
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) AS rolling_people_vaccinated
    FROM covid_deaths AS dea
    JOIN covid_vaccination AS vac
        ON dea.location = vac.location
       AND dea.date = vac.date
    WHERE dea.continent IS NOT NULL
)
SELECT
    *,
    (rolling_people_vaccinated
        / NULLIF(population::numeric, 0)) * 100
        AS percent_population_vaccinated
FROM popvsvac
ORDER BY location, date;
---3. Temporary table in PostgreSQL
---Query 11: Create and populate the temporary table
DROP TABLE IF EXISTS percent_population_vaccinated_temp;

CREATE TEMP TABLE percent_population_vaccinated_temp AS
SELECT
    dea.continent,
    dea.location,
    dea.date,
    dea.population,
    vac.new_vaccinations,
    SUM(COALESCE(vac.new_vaccinations::numeric, 0))
        OVER (
            PARTITION BY dea.location
            ORDER BY dea.date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS rolling_people_vaccinated
FROM covid_deaths AS dea
JOIN covid_vaccination AS vac
    ON dea.location = vac.location
   AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;
---Query 12: Calculate the percentage from the temporary table
SELECT
    *,
    (rolling_people_vaccinated
        / NULLIF(population::numeric, 0)) * 100
        AS percent_population_vaccinated
FROM percent_population_vaccinated_temp
ORDER BY location, date;
---4. Create a view for later visualization
--Query 13: Create the vaccination view
CREATE OR REPLACE VIEW percent_population_vaccinated AS
SELECT
    dea.continent,
    dea.location,
    dea.date,
    dea.population,
    vac.new_vaccinations,
    SUM(COALESCE(vac.new_vaccinations::numeric, 0))
        OVER (
            PARTITION BY dea.location
            ORDER BY dea.date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS rolling_people_vaccinated
FROM covid_deaths AS dea
JOIN covid_vaccination AS vac
    ON dea.location = vac.location
   AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;
--Query 14: Test the view
SELECT
    *,
    (rolling_people_vaccinated
        / NULLIF(population::numeric, 0)) * 100
        AS percent_population_vaccinated
FROM percent_population_vaccinated
ORDER BY location, date;
--5. Important checks before running the script
---Because your dataset was imported from CSV, first verify the actual column names and data types.
SELECT
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('covid_deaths', 'covid_vaccination')
ORDER BY table_name, ordinal_position;
--Validate the join and data types

--A. Check duplicate location/date records
SELECT location, date, COUNT(*) AS record_count
FROM covid_deaths
GROUP BY location, date
HAVING COUNT(*) > 1;

SELECT location, date, COUNT(*) AS record_count
FROM covid_vaccination
GROUP BY location, date
HAVING COUNT(*) > 1;
--B. Check column data types
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_name IN ('covid_deaths', 'covid_vaccination')
  AND column_name IN (
      'location', 'date', 'population',
      'total_deaths', 'new_vaccinations'
  )
ORDER BY table_name, ordinal_position;
--C. Check whether the join loses records
SELECT
    COUNT(*) AS matching_location_date_rows
FROM covid_deaths AS dea
JOIN covid_vaccination AS vac
    ON dea.location = vac.location
   AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;
