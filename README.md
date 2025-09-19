# Batch ELT on Azure (Dev) — Raw → Staging → Core

> **TL;DR**: This project implements an **ADF-first batch ELT** that lands Parquet to **ADLS Gen2 (raw)**, loads **idempotently** to **Synapse (staging)**, and transforms to **Core** (cleaned, deduped, canonicalized) with **DQ gates**, **run logging**, **observability**, and an **orchestrator** pipeline. Optional governance via **Microsoft Purview** shows lineage *(raw file → ADF → staging → core)*.

---

## 1) Source & Landing (raw)

- Land source files **as-is** to `adls/raw/<dataset>/ingest_date=YYYY-MM-DD/`.
- Keep raw immutable for backfills/replay and full lineage.
- Ingestion handled by existing utilities / ADF copy (outside the scope of this README).

---

## 2) Staging

- Pipeline: **`pl_raw_to_stg_nyctaxi`**
- What it does: copies landed files to **`stg.trip`** with minimal typing + lineage columns (`ingest_date`, `source_file_name`, `loaded_at`).
- DQ (light): rowcount>0, non-null pickup timestamp, negative fare warnings.
- Logging: writes to **`ops.run_log`** and **`ops.dq_result`**.

---

## 3) Transformation (staging → core)

**Goal:** Clean types, filter junk, dedupe deterministically, and produce business-ready **core** tables.

- Pipeline: **`pl_stg_to_core_nyctaxi`** *(called by the orchestrator)*
- Steps:
  1. **Build slice via CTAS** (normalize types, units/codes; drop obviously bad rows)
  2. **Quarantine rejects** in `err.trip` (idempotent per `ingest_date`)
  3. **Load `core.trip_clean`** (delete slice → dedupe → insert), write **`ops.run_metrics`**
  4. **Core DQ gate** (hard fails on zero rows, time order, negatives, null key timestamps, duplicates)
  5. **Run logging** to `ops.run_log`

**Distribution/Index:** `core.trip_clean` uses **ROUND_ROBIN** + **CCI**.  
**Note:** NYC Taxi has no durable `trip_id`; a deterministic `trip_sk` may be introduced in **Modeling**.

👉 Full details & queries: **[sql/docs/README_transform.md](sql/docs/README_transform.md)**  
👉 Column contracts & rules: **[sql/docs/data_dictionary.md](sql/docs/data_dictionary.md)**

---

## 4) Scheduling & Backfill

- **Single trigger on the orchestrator**: **`pl_daily_nyctaxi`** runs → `pl_raw_to_stg_nyctaxi` → `pl_stg_to_core_nyctaxi` in order.
- **Daily schedule**: Trigger `t_daily_nyctaxi` at the desired UTC time.
- **Backfill**:
  - *Option A:* Run the orchestrator with specific `run_date` values (Debug/Trigger now).
  - *Option B:* A simple backfill pipeline that iterates over a list of dates (same code path).

---

## 5) Observability & Alerts

**Tables**
- `ops.run_log` — stage run status/timing + rows copied
- `ops.run_metrics` — rows in/out/err per `ingest_date`
- `ops.dq_result` — per-check results (staging + core)

**Alerts (Azure Monitor)**
- **Pipeline failed runs > 0** on pipeline **`pl_daily_nyctaxi`** (primary “red” signal)
- *(Optional)* **Activity failed runs > 0** filtered to `pl_daily_nyctaxi`
- *(Optional)* **Pipeline run duration > N minutes** (slowdown detection)

---

## 6) Governance (Purview)

- **ADLS scans**: scope to `raw/`, `stg/`, `core/` paths using Purview’s managed identity (Storage Blob Data Reader role).
- **SQL scan**: register & scan the **Dedicated SQL pool** (grant `db_datareader` + `VIEW DEFINITION` to Purview MI).
- **ADF ↔ Purview**: connect the factory to Purview to stitch pipeline lineage.
- **Lineage** expected: `raw file → (ADF Copy) → stg.trip → (Script) → core.trip_clean`.
- **Glossary/Classifications**: add business terms and (if needed) PII tags.

---

## 7) Repository layout

```text
infra/terraform/           # Azure resources (ADLS, ADF, Synapse, Purview, RBAC)
ingest/                    # Dev landing utilities (upload/backfill scripts)
  upload_raw.sh
  backfill_dates.sh
sql/                       # DDL/DML (staging, core, ref, err, ops)
  docs/
    data_dictionary.md     # Authoritative column contracts and rules
    README_transform.md    # Transformation (Staging → Core) runbook
adf/                       # (optional) ADF factory JSON if checked-in
docs/
  img/                     # screenshots/diagrams
README.md                  # ← this file
```

---

## 8) Operations runbook

**Re-run a day (end-to-end)**  
- ADF → Monitor → Pipelines → **`pl_daily_nyctaxi`** → *Trigger now*  
  - `dataset = nyctaxi_yellow`  
  - `run_date = YYYY-MM-DD`

**Where to look when red**
- ADF/Synapse **Monitor → Pipeline runs** (drill into activity)  
- `SELECT TOP 50 * FROM ops.run_log ORDER BY started_at_utc DESC;`  
- `SELECT TOP 50 * FROM ops.run_metrics ORDER BY run_ts_utc DESC;`  
- `SELECT TOP 50 * FROM ops.dq_result ORDER BY created_at_utc DESC;`

**Common triage**
- DQ fails → inspect **CoreDQ_Gate** output; fix data/rules; rerun the date.
- `core + err > stg` → ensure quarantine step deletes for the slice; ensure `ref.payment_type_map` has one active mapping per src.

---

## 9) Security

- **AuthN**: Managed Identity for ADF/Synapse; no keys in code.
- **AuthZ**: RBAC (least privilege); restrict storage & SQL to pipeline identities.
- **Secrets**: Key Vault (for any legacy secrets); linked services use MI where possible.
- **Networking**: Private endpoints/firewall (as needed).

---

## 10) Roadmap (next phase — Modeling: Core → Star)

- **Dimensions**: `dim_date`, `dim_time`, `dim_vendor`, `dim_payment_type`, optional `dim_location`
- **Fact**: `fact_trip` (grain = cleaned trip), conformed FKs to dims
- **Physical design**:
  - Facts: **CCI**; consider **HASH** on a stable FK to reduce data movement
  - Small dims: **REPLICATE**
- **Keys**: consider deterministic `trip_sk` in model for joins (hash of core dedupe columns)
- **Semantic layer**: Power BI model over the star with consistent measures

---

## Related docs
- Transform runbook: **[sql/docs/README_transform.md](sql/docs/README_transform.md)**
- Data dictionary:  **[sql/docs/data_dictionary.md](sql/docs/data_dictionary.md)**
