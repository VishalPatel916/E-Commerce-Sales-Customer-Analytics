"""Load the nine Olist CSVs into a SQLite database (data/olist.db).

Usage:  python src/build_db.py
"""
import sqlite3
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
DB = DATA / "olist.db"

# csv file -> (table, column rename map or None)
TABLES = {
    "olist_customers_dataset.csv": ("customers", None),
    "olist_sellers_dataset.csv": ("sellers", None),
    "product_category_name_translation.csv": ("category_translation", None),
    "olist_products_dataset.csv": ("products", None),
    "olist_orders_dataset.csv": ("orders", None),
    "olist_order_items_dataset.csv": ("order_items", None),
    "olist_order_payments_dataset.csv": ("payments", None),
    "olist_order_reviews_dataset.csv": ("reviews", None),
    "olist_geolocation_dataset.csv": ("geolocation", None),
}


def main() -> None:
    con = sqlite3.connect(DB)
    con.executescript((ROOT / "sql" / "schema.sql").read_text())
    for csv, (table, _) in TABLES.items():
        df = pd.read_csv(DATA / csv, dtype=str, keep_default_na=True)
        cols = [r[1] for r in con.execute(f"PRAGMA table_info({table})")]
        df = df[cols]
        for c in cols:  # restore numeric types for numeric columns
            ctype = [r[2] for r in con.execute(f"PRAGMA table_info({table})") if r[1] == c][0]
            if ctype in ("INTEGER", "REAL"):
                df[c] = pd.to_numeric(df[c], errors="coerce")
        df.to_sql(table, con, if_exists="append", index=False, chunksize=50_000)
        n = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        print(f"{table:22s} {n:>9,d} rows")
    con.commit()
    con.close()


if __name__ == "__main__":
    main()
