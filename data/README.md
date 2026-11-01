# Data

Raw data is **not committed** (size + licence: CC BY-NC-SA 4.0).

## Get the data
**Official source:** [Olist Brazilian E-Commerce Public Dataset on Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

```bash
# option 1: Kaggle CLI (needs ~/.kaggle/kaggle.json)
kaggle datasets download -d olistbr/brazilian-ecommerce -p data --unzip

# option 2: manual download from the Kaggle page, unzip the 9 CSVs into this folder
```

> This project was built from a public Hugging Face mirror of the same nine files
> (`bulutttt/olist-raw-data`) because no Kaggle credentials were available. Row counts match the
> official dataset (99,441 orders · 112,650 items · 103,886 payments · 99,224 reviews · 32,951 products).

## Expected files
`olist_orders_dataset.csv`, `olist_order_items_dataset.csv`, `olist_customers_dataset.csv`,
`olist_products_dataset.csv`, `olist_order_payments_dataset.csv`, `olist_order_reviews_dataset.csv`,
`olist_sellers_dataset.csv`, `olist_geolocation_dataset.csv`, `product_category_name_translation.csv`

## Generated (git-ignored)
- `olist.db` — SQLite database built by `src/build_db.py`
- `processed/order_facts.csv.gz` — one-row-per-order analysis table built in notebook 02
