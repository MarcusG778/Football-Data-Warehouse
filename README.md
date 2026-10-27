<<<<<<< HEAD
# Football Data Warehouse

A football data warehouse and analytics project combining FBref and Understat data using Python, PostgreSQL, and dbt. The project focuses on player-season statistics, player identity resolution, and data modelling for downstream Power BI analytics.

## Project Overview

The warehouse integrates football statistics from multiple sources into a consistent analytical data model. It aims to support reliable player-season comparisons across FBref and Understat, with automated entity resolution and transformations managed through dbt.

### Key Features

- **Multi-source data integration:** Combines FBref and Understat football statistics.
- **Data warehousing:** Uses PostgreSQL to store and manage football data.
- **Data transformation:** Uses dbt to build staging and intermediate models.
- **Player identity resolution:** Uses name mapping and fuzzy matching to help reconcile player records across sources.
- **BI readiness:** Designed to support analytical reporting and Power BI dashboards.

## Technology Stack

- Python
- PostgreSQL
- dbt
- FBref
- Understat
- Power BI

## Getting Started

### Prerequisites

Install Python, PostgreSQL, and dbt with the appropriate PostgreSQL adapter. Configure the database connection in your dbt profile before running the project.

### Run the dbt project

Build the models:

```bash
dbt run
```

Run the configured tests:

```bash
dbt test
```

Load or refresh seed data:

```bash
dbt seed
```

## Project Status

The project is under active development. Data integration, player crosswalks, data quality checks, and analytical models are being refined as the warehouse evolves.

## Resources

- [dbt documentation](https://docs.getdbt.com/docs/introduction)
- [dbt Community](https://discourse.getdbt.com/)
- [dbt blog](https://www.getdbt.com/blog/)

>>>>>>> db5bbbde0ccfeffa1a6d1d28fd459a7b03142d1f
