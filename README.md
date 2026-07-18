# snowflake-powerbi-data-warehouse

Case studies, capability builds, and supporting technical assets for RUSA Analytics (rusaanalytics.com).

Repo: https://github.com/rusa-analytics/snowflake-powerbi-data-warehouse

## Case studies

Snowflake data warehouse + Power BI reporting layer tracking price, production, and supply concentration across Lithium, Graphite, Manganese, and Cobalt.

- `dashboard.html` — self-contained interactive dashboard, safe to embed via iframe or Wix Custom Code
- `snowflake_setup.sql` — warehouse/database/schema build script (raw → core → reporting)
- `powerbi_integration_guide.md` — connection method, semantic model, DAX measures
- `data/` — synthetic source dataset (fact + dimension tables) used to build the warehouse

**Note:** this is an illustrative capability build. "Meridian Resource Partners" is a representative client name, not a live engagement — see `case-study.md` for the internal notes on this framing.
