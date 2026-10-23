# COVID-19 Data Exploration Using PostgreSQL

## Project Overview
This project analyzes COVID-19 cases, deaths, population, and vaccination data using PostgreSQL. The goal was to identify trends, compare reported outcomes across locations, and explore vaccination progress using SQL.

## Tools Used
- PostgreSQL
- pgAdmin
- GitHub

## SQL Skills
- Data filtering and sorting
- Aggregate functions (`SUM`, `MAX`)
- `GROUP BY` and `ORDER BY`
- Joins
- Common Table Expressions (CTEs)
- Window functions
- Temporary tables and views
- Data validation and duplicate checks

## Key Insights

### 1. Global COVID-19 Statistics
- Total reported cases: **150,574,977**
- Total reported deaths: **3,180,206**
- Reported case-fatality percentage: **2.11%**

**Insight:** Reported deaths represented 2.11% of reported cases in the analyzed dataset. This is a reported case-fatality percentage, not the infection fatality rate.

### 2. Locations with the Highest Reported Infection Rates
- **Andorra:** 17.13% — 13,232 reported cases out of a population of 77,265.
- **Montenegro:** 15.51% — 97,389 reported cases.
- **Czechia:** 15.23% — 1,630,758 reported cases.
- **San Marino:** 14.93% — 5,066 reported cases.
- **Slovenia:** 11.56% — 240,292 reported cases.

**Insight:** Andorra had the highest reported cases-to-population ratio among the five locations returned by the query.

### 3. Continent-Level Reported Deaths
According to the continent-level results provided:
- Europe: **1,016,750**
- North America: **847,942**
- South America: **672,415**
- Asia: **520,286**
- Africa: **121,784**
- Oceania: **1,046**

**Insight:** Europe had the highest reported death total in the supplied results, followed by North America and South America.

*Note: Verify these figures against the corrected continent-level query before publishing them as final results.*

### 4. Vaccination Analysis
The project joined the COVID deaths and vaccination tables using location and date. A window function calculated cumulative reported vaccination doses over time.

**Example:** Gibraltar recorded 61,357 cumulative reported doses for a population of 33,691 by April 30, 2021, equivalent to approximately **182.12 doses per 100 people**.

**Insight:** Doses per 100 people can exceed 100 because an individual may receive multiple doses. This metric does not represent the percentage of unique people vaccinated.

## Data Validation
- Checked for duplicate location-date records.
- Reviewed column names and data types.
- Checked matching records between the deaths and vaccination tables.

These checks help improve the reliability of SQL analysis.

## Conclusion
This project strengthened my practical PostgreSQL skills in data exploration, aggregation, joins, CTEs, window functions, and data validation. It also demonstrated how SQL can be used to analyze healthcare data and communicate meaningful insights from reported COVID-19 trends.

