# Streaming + Batch ELT → Synapse DW (Hourly + Backfill)

**One‑liner:** Event Hubs & ASA land **raw/curated/DLQ** to ADLS; ADF loads Synapse **hourly** (with backfill). Batch ELT shares the **same model**. Power BI shows **Last Updated / Latency** so freshness is clear.

**Why it matters:** Reliable, idempotent warehouse loads with DLQ, alerts, and range backfills. A single source of truth powers BI from both streaming and batch.

---

## Architecture (high level)

```
                 ┌────────────────────────────── Streaming Lane ──────────────────────────────┐
Producer(s) → Event Hubs → Stream Analytics (parse + DQ) → ADLS Gen2
                                     ├─ Raw JSONL  → streaming/…/date=YYYY/MM/DD/time=HH/…
                                     ├─ Curated CSV → streaming-curated/…/date=…/time=…/…
                                     └─ DLQ JSON    → streaming-dlq/…/date=…/time=…/…
                                     |
                                     └→ ADF hour pipeline → Synapse (stg → slice → dims → fact)
                                              └→ Backfill wrapper (lastHour | fixedHour | range)

                 └────────────────────────────── Batch ELT Lane ───────────────────────────────┘
Batch files (landing) → ADF (copy/transform) → Synapse (stg → core → mdl.* same model tables)

Power BI → reads from Synapse view (shared by batch & streaming)
```

**Core ideas**
- **Separate concerns**: stream continuously to the lake; micro‑batch the warehouse (hourly) for reliability & cost.
- **Synapse‑safe upsert**: update‑then‑insert (no reliance on `@@ROWCOUNT`/`MERGE OUTPUT`). 
- **Run‑scoped purge**: delete `core.trip_clean_slice` by `_runId` after each model load (clean reruns/backfills).
- **Shared model**: both lanes feed `mdl.fact_trip` & dims → BI stays unchanged.

---

## What’s included

- **Streaming**
  - ASA wiring: parse/enrich; three sinks (raw/curated/DLQ) with hourly partitioning.
  - ADF hour pipeline: Copy curated → staging; build slice; upsert dims & fact; purge slice; log.
  - Backfill: wrapper supports **lastHour / fixedHour / range** (hour‑by‑hour loop).
- **Batch ELT**
  - Existing pipelines to load the same **mdl** model (fact + dims), aligned keys.
- **Model**
  - `mdl.fact_trip`: `CHAR(64)` SHA‑256 `trip_id`, **DISTRIBUTION = HASH(trip_id)**, **CLUSTERED COLUMNSTORE**.
  - Dims: vendor, payment, location (replicate). Rate/flag optional.
  - BI view: `mdl.vw_fact_trip_bi` (flattened with freshness fields).
- **BI**
  - Power BI report with **Trips**, **Total Fare**, **Tip %**, **Last Updated (UTC)** & **Latency (min)** cards.
- **Ops**
  - Hourly trigger; Azure Monitor alerts (ADF/ASA/EH/SQL); ADLS lifecycle rules; RBAC via MSI where possible.

---

## Key design choices (short)

- **Idempotent upsert**: stage → **UPDATE** matched diffs → **INSERT** new → counts via temp tables; expose counts via a 1‑row `SELECT` or log inside SP.
- **Distribution strategy**: big fact **HASH(trip_id)** + CCI; small dims **REPLICATE** → avoids runtime **shuffles**.
- **Backfill simplicity**: wrapper with an **Until** loop: process hour → bump hour → repeat.
- **Quality**: curated = rows that pass DQ; DLQ = rejects with reason; raw = full fidelity.

---

## Quality & lineage (optional roadmap)

- **Row‑level data quality counters** *(M)*  
  Count per run: `good_rows`, `dlq_rows`, `negative_fare`, `bad_duration`, `null_vendor`, etc. Log in audit or a dedicated table.
- **Purview lineage** *(L)*  
  Register EH, ASA, ADLS, ADF, Synapse. Expected lineage: **EH → ASA → ADLS → ADF → Synapse**.

---

## Operating the solution (at a glance)

- **Hourly**: trigger runs the hour pipeline for the **last completed hour**.
- **Backfill**: set `startHourUtc`/`endHourUtc` (ISO hour). Wrapper loops hours and calls the hour pipeline each iteration.
- **Reruns**: safe; run‑scoped purge ensures clean idempotent loads.
- **Alerts** (Azure Monitor): 
  - ADF: Pipeline/Activity failed runs.
  - ASA: Watermark delay/backlog, job status.
  - Event Hubs: Throttled requests, server errors.
  - Synapse: CPU/tempdb/queue depth.
  - Storage (optional): availability/5xx.
- **Lifecycle**: curated → Cool @7d, delete @30–60d; DLQ longer; staging cleanup @7d.

---

## Verification quick checks

- Slice purged: `SELECT COUNT(*) FROM core.trip_clean_slice WHERE _runId='<RunId>';` → **0**.
- Fact touched recently: `SELECT TOP 5 trip_id, last_upsert_at FROM mdl.fact_trip ORDER BY last_upsert_at DESC;`.
- Power BI freshness: **Last Updated** card matches last successful hour; **Latency (min)** sane.

---

## Repo map

```
/infra        # Bicep/ARM + GitHub Actions (deploy EH/ASA/ADLS/alerts/pipelines)
/asa          # asa-wire.sh (job wiring + inputs/outputs/query)
/adf          # pipelines (JSON); backfill wrapper + range
/sql          # DDL (tables); procs (slice/dims/fact/purge); BI view
/bi           # PBIX or screenshots
README.md     # (this file) — high-level overview
README_BATCHELT.md   # Batch ELT details
README_STREAMING.md  # Streaming details
```

---

## Glossary (2 lines each)

- **OLTP vs OLAP** — app DB for transactions vs. warehouse for analytics.  
- **MPP** — massively parallel workers; avoid **shuffles** via **HASH(key)** on big joins, **REPLICATE** small dims.  
- **CTAS + CCI** — fast (re)build with the right distribution; columnstore for scan speed.  
- **DLQ** — rejected rows with a reason; curated ingests only good rows.

---

## Links

- **Batch ELT (detailed):** `README_BATCHELT.md`  
- **Streaming (detailed):** `README_STREAMING.md`

---

## License
MIT (or your preferred license).
