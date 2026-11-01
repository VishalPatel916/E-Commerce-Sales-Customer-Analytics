# SQL layer

| File | Purpose |
|------|---------|
| `schema.sql` | Tables, primary/foreign keys, indexes (SQLite dialect, types map 1:1 to PostgreSQL) |
| `analysis_queries.sql` | 20 analytical queries, each tagged `-- name:` / `-- question:` |

Run everything: `python src/build_db.py && python src/run_sql.py` → results in `reports/sql_results/*.csv` and `reports/sql_results.md`.

**SQL features covered:** multi-table JOINs (3–4 tables) · GROUP BY / HAVING · CTEs (chained) · subqueries (scalar, derived table, in HAVING) · CASE · window functions `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `LAG`, running `SUM() OVER`, `SUM(SUM())`-style share-of-total · date arithmetic.

## Why SQLite and how to port to PostgreSQL
PostgreSQL was not installed in the build environment (the brief allows SQLite as a fallback), so the project runs on SQLite. Only a few date functions differ:

| SQLite (used) | PostgreSQL |
|---|---|
| `strftime('%Y-%m', ts)` | `TO_CHAR(ts, 'YYYY-MM')` or `DATE_TRUNC('month', ts)` |
| `julianday(a) - julianday(b)` | `EXTRACT(EPOCH FROM (a - b)) / 86400` |
| `strftime('%w', ts)` / `%H` | `EXTRACT(DOW FROM ts)` / `EXTRACT(HOUR FROM ts)` |
| `TEXT` timestamps | `TIMESTAMP` |
| `CAST(x AS INT)` | works as-is |

Load the CSVs with `\copy table FROM 'file.csv' CSV HEADER` after creating the schema.

## Grain rule (most important)
`order_items` and `payments` are both many-rows-per-order. Joining them directly multiplies rows and inflated revenue by **4.5%** in this dataset (see notebook 02). Every query that combines them (q13, q17, q19) pre-aggregates each side to one row per order in a CTE first.
