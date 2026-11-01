"""Shared loading / cleaning helpers for the Olist notebooks.

Grain rules (the #1 source of wrong numbers in this dataset):
  * order_items  -> many rows per order
  * payments     -> many rows per order
  * reviews      -> usually 1, sometimes >1 rows per order
Each is aggregated to ONE row per order *before* joining -> `build_order_facts()`.
"""
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
VIZ = ROOT / "visualizations"
PROCESSED = DATA / "processed"

FILES = {
    "orders": "olist_orders_dataset.csv",
    "items": "olist_order_items_dataset.csv",
    "customers": "olist_customers_dataset.csv",
    "products": "olist_products_dataset.csv",
    "payments": "olist_order_payments_dataset.csv",
    "reviews": "olist_order_reviews_dataset.csv",
    "sellers": "olist_sellers_dataset.csv",
    "translation": "product_category_name_translation.csv",
    "geolocation": "olist_geolocation_dataset.csv",
}
ORDER_DATE_COLS = [
    "order_purchase_timestamp", "order_approved_at", "order_delivered_carrier_date",
    "order_delivered_customer_date", "order_estimated_delivery_date",
]

# Trend analysis window: 2016 and Sep-Oct 2018 contain only a handful of orders
# (see notebook 01), so month-level trends use full months only.
TREND_START, TREND_END = "2017-01-01", "2018-09-01"


def load_raw(only=None) -> dict:
    names = only or list(FILES)
    return {k: pd.read_csv(DATA / FILES[k]) for k in names}


def clean_orders(orders: pd.DataFrame) -> pd.DataFrame:
    o = orders.copy()
    for c in ORDER_DATE_COLS:
        o[c] = pd.to_datetime(o[c], errors="coerce")
    o["purchase_month"] = o["order_purchase_timestamp"].dt.to_period("M")
    o["delivery_days"] = (o["order_delivered_customer_date"] - o["order_purchase_timestamp"]).dt.total_seconds() / 86400
    o["days_vs_estimate"] = (o["order_delivered_customer_date"] - o["order_estimated_delivery_date"]).dt.total_seconds() / 86400
    # Analysable delivered order: status delivered AND a delivery date exists (8 'delivered' rows have none).
    o["is_delivered"] = (o["order_status"] == "delivered") & o["order_delivered_customer_date"].notna()
    # Documented rule: late = delivered strictly after the estimated delivery date.
    o["is_late"] = np.where(o["is_delivered"], o["order_delivered_customer_date"] > o["order_estimated_delivery_date"], np.nan)
    return o


def build_order_facts(t: dict) -> pd.DataFrame:
    """One row per order with items / payment / review / customer attributes attached."""
    o = clean_orders(t["orders"])

    it = t["items"]
    items_agg = it.groupby("order_id").agg(
        n_items=("order_item_id", "count"),
        item_revenue=("price", "sum"),
        freight=("freight_value", "sum"),
        n_sellers=("seller_id", "nunique"),
        n_products=("product_id", "nunique"),
    )

    pay = t["payments"]
    pay_agg = pay.groupby("order_id").agg(
        payment_value=("payment_value", "sum"),
        n_payment_rows=("payment_sequential", "count"),
        max_installments=("payment_installments", "max"),
    )
    # payment type of the largest payment row = the order's "main" payment type
    main_pay = (pay.sort_values("payment_value", ascending=False)
                   .drop_duplicates("order_id")
                   .set_index("order_id")["payment_type"].rename("main_payment_type"))

    rv = t["reviews"].copy()
    rv["review_answer_timestamp"] = pd.to_datetime(rv["review_answer_timestamp"], errors="coerce")
    # An order can have >1 review: keep the most recent one -> an integer 1-5 ordinal score.
    rv = (rv.sort_values("review_answer_timestamp")
            .drop_duplicates("order_id", keep="last")
            .set_index("order_id")[["review_score"]])

    cust = t["customers"].set_index("customer_id")[["customer_unique_id", "customer_city", "customer_state"]]

    f = (o.set_index("order_id")
           .join(items_agg).join(pay_agg).join(main_pay).join(rv)
           .join(cust, on="customer_id"))
    f["total_value"] = f["item_revenue"] + f["freight"]
    return f.reset_index()


def category_table(t: dict) -> pd.DataFrame:
    p = t["products"].merge(t["translation"], on="product_category_name", how="left")
    p["category"] = p["product_category_name_english"].fillna(p["product_category_name"]).fillna("unknown")
    return p


def in_trend_window(df: pd.DataFrame, col: str = "order_purchase_timestamp") -> pd.DataFrame:
    return df[(df[col] >= TREND_START) & (df[col] < TREND_END)]


def setup_plots():
    import matplotlib.pyplot as plt
    import seaborn as sns
    sns.set_theme(style="whitegrid", context="notebook")
    plt.rcParams.update({"figure.dpi": 100, "axes.titleweight": "bold", "axes.titlesize": 13,
                         "axes.spines.top": False, "axes.spines.right": False})
    VIZ.mkdir(exist_ok=True)


def save_fig(fig, name: str) -> None:
    VIZ.mkdir(exist_ok=True)
    fig.savefig(VIZ / name, dpi=150, bbox_inches="tight")
