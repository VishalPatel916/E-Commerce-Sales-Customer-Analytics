# Project Report — what was built and why

## 1. Brief → deliverable map

| Brief requirement | Delivered | Where |
|---|---|---|
| Download Olist dataset, record source | All 9 CSVs, row counts verified against the official dataset; source + download instructions documented | `data/README.md` |
| Inspect all nine files, map relationships & keys, data dictionary | Shape/dtype/null/duplicate/key-uniqueness/orphan-key checks, relationship diagram | `notebooks/01_data_exploration.ipynb` |
| Cleaning & validation, document every decision | 8 documented decisions with evidence, cleaning log table, reconciliation of money fields, pandas↔SQL cross-check | `notebooks/02_data_cleaning.ipynb`, `src/olist.py` |
| Load into a relational DB with keys | SQLite DB with PKs, FKs, indexes | `sql/schema.sql`, `src/build_db.py` |
| 15–20 SQL queries (joins ≥3 tables, GROUP BY/HAVING, CTEs, subqueries, CASE, windows) | **20 queries**, each with the business question it answers | `sql/analysis_queries.sql`, `reports/sql_results.md` |
| EDA, 8–10 labeled charts with interpretation | **21 charts**, each with a written interpretation | `notebooks/03`, `04`, `visualizations/` |
| Descriptive statistics | Mean/median/SD/variance/range/IQR/quartiles/skew/kurtosis/outlier share + Spearman correlation | `notebooks/05` |
| Two inferential investigations (question, H₀/H₁, test & why, assumptions, statistic/p, CI/effect, conclusion) | (1) late delivery vs review score — Welch, Mann–Whitney, bootstrap CI, Cohen's d; (2) payment value by type — Kruskal–Wallis, log-ANOVA, Holm-corrected post-hoc, ε²/η² | `notebooks/05` |
| 5–8 evidence-backed insights using the Observation/Evidence/Interpretation/Recommendation/Limitation template | 9 insights in that exact template | `README.md` |
| GitHub-ready repo, README, requirements, reproducibility | README, requirements.txt, .gitignore, `run_all.sh` | root |
| Optional: ML late-delivery prototype | Time-split, leakage-free, baselines, PR-AUC | `notebooks/06` |
| Optional: A/B test (separate, simulated) | Clearly labelled synthetic; power, SRM, z-test, CI | `notebooks/07` |
| Optional: Power BI dashboard | **Not done** (needs Power BI Desktop; brief marks it optional) | — |
| Resume bullet | See §4 — to be used only after you have reviewed the work | below |

## 2. Deviations & honest notes

1. **SQLite instead of PostgreSQL.** PostgreSQL wasn't installed; the brief explicitly allows SQLite. Syntax differences are tiny and documented in `sql/README.md`.
2. **Data source mirror.** No Kaggle credentials were available, so the nine CSVs came from a public Hugging Face mirror (`bulutttt/olist-raw-data`). Row counts match the official dataset exactly (99,441 / 112,650 / 103,886 / 99,224 / 32,951 …). Re-download from Kaggle with the commands in `data/README.md` for a fully official copy.
3. **No findings were invented.** Every number in README comes from executed notebook/SQL output. Several first-draft interpretation sentences did not match the outputs and were corrected (e.g. revenue growth "~9×" → 8.3×; "half of card payments use instalments" → 66.9%; voucher median).
4. **Statistical honesty.** With ~96k rows nearly any test is "significant", so effect sizes are reported alongside p-values. The payment-type result is statistically significant but practically tiny (ε² = 0.009) and is reported that way.
5. **ML is modest by design.** ROC-AUC ≈ 0.70. The prototype is reported as-is rather than tuned to look impressive.
6. **A/B notebook is simulated** and says so at the top; its run is deliberately under-powered and discussed as such.
7. **Big data / NoSQL.** The brief says not to claim Hadoop/Spark/NoSQL experience from this project — this project does not.

## 3. Key technical decisions
- **Grain discipline:** every many-per-order table is aggregated to order grain before joining (naive join inflated revenue 4.5%).
- **Metric definitions kept separate:** `item_revenue` (price), `total_value` (price + freight), `payment_value` (cash paid).
- **`customer_unique_id`** (not `customer_id`) for repeat-purchase analysis.
- **Trend window 2017-01 → 2018-08** because other months are sparse (otherwise MoM growth of +29,777% appears).
- **Reviews:** latest review per order in pandas (integer 1–5 for rank tests); SQL averages duplicates — affects 547 orders, documented.
- **Outliers kept**; skew handled with medians, log scales and rank tests.
- **ML:** only checkout-time features, chronological split, baselines first, PR-AUC against prevalence.

## 4. Resume bullet (verified numbers — edit to taste, only claim what you can explain)
**E-Commerce Sales & Customer Analytics** | Python, Pandas, NumPy, SQL, Matplotlib, Seaborn, SciPy, scikit-learn
- Performed end-to-end EDA and data validation on ~99K orders across 9 relational tables; identified and fixed a join fan-out that inflated revenue by 4.5%.
- Wrote 20 SQL queries (multi-table joins, chained CTEs, window functions, cohort retention) and reconciled results against an independent pandas pipeline.
- Tested whether late delivery lowers review scores (Welch t, Mann–Whitney, bootstrap CI): late orders scored 1.73★ lower (d = −1.45), generating 34% of all 1–2★ reviews from 8% of orders.
- Delivered 9 evidence-backed business recommendations with 21 charts; built a time-split late-delivery model (ROC-AUC 0.70) and reported its limits honestly.

> Before using this: be ready to explain every metric, join, cleaning decision, chart and test (the brief's final checklist item). Notebooks 02 and 05 are written to help with that.

## 5. Completion checklist (from the brief)
- [x] Downloaded Olist dataset and recorded its source
- [x] Inspected all nine files; documented relationships
- [x] Data-quality checks and cleaning documented
- [x] Tables loaded into a relational DB (SQLite)
- [x] 20 SQL queries incl. CTEs and window functions
- [x] 21 interpretable visualizations
- [x] Descriptive statistics
- [x] Two statistical investigations with assumptions and interpretation
- [x] 9 evidence-backed insights and recommendations
- [x] Reproducible repo with README
- [ ] Power BI dashboard (optional, skipped)
- [ ] **You** being able to explain every part — review the notebooks before interviews
