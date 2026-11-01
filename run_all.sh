#!/usr/bin/env bash
# Reproduce everything from the raw CSVs in data/.
set -euo pipefail
cd "$(dirname "$0")"
python src/build_db.py          # CSV -> SQLite
python src/run_sql.py           # 20 SQL queries -> reports/
cd notebooks
for nb in 01_data_exploration 02_data_cleaning 03_sales_analysis 04_customer_analysis \
          05_statistical_analysis 06_late_delivery_model 07_ab_test_simulation; do
  jupyter nbconvert --to notebook --execute --inplace "$nb.ipynb"   # order matters: 02 writes data/processed
done
