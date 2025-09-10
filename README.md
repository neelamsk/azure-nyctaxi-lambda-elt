# Demo Project - Batch ELT on Azure

## Executive Summary

I have built a production-style Batch ELT on Azure using Terraform + ADF + Synapse.

* Automated daily ingestion of NYC Taxi CSVs into ADLS Gen2 with date partitions.

* Loaded raw → staging → clean (core) → star schema (facts/dims) in Synapse Dedicated SQL Pool.

* Wrote data quality checks, added run logs/lineage, and captured pipeline screenshots.

* Produced KPI queries and BI screenshots.
Skills: Azure IaC (Terraform), ADF pipelines, Synapse SQL (MPP, columnstore, distribution), data modeling, DQ/monitoring, cost hygiene (pause/resume).
Why it matters: demonstrates end-to-end data engineering, reproducibility, and cloud ops discipline.

A showcase, end-to-end **Batch ELT** pipeline on Azure:
**ADLS Gen2 (raw)** → **Azure Data Factory (ingest)** → **Synapse SQL (staging → core → model)** → **BI (screenshots + SQL notebook)**

## Architecture
![Architecture](./architecture.png)
<small>(Add this image later; for now, the sections below explain the flow.)</small>

**Flow**
1. **Ingest** NYC Taxi CSVs into **ADLS Gen2** under `raw/nyc_taxi/ingest_date=YYYY-MM-DD/`.
2. **ADF** copies raw files → **Synapse (staging tables)** and writes lineage columns.
3. ELT SQL builds **core** (clean) and **model** (facts/dims) tables in Synapse.
4. **Analytics** SQL produces KPIs; screenshots go into `reports/`.
5. **Tests** run basic data-quality checks (row counts, nulls, duplicates, FK coverage).

## Tech & choices
- **Orchestration:** Azure Data Factory (ADF)
- **Warehouse:** Synapse Dedicated SQL Pool (DW100c)
- **Data Lake:** ADLS Gen2 (Hierarchical Namespace on)
- **IaC:** Terraform
- **Partitioning:** `ingest_date=YYYY-MM-DD` folders (repeatable loads + pruning)

## Repo layout (key folders)
- `infra/terraform/` – Terraform for RG, Storage (ADLS), ADF, Synapse workspace + SQL pool  
- `orchestration/adf/` – exported ADF pipeline JSONs (pipelines, datasets, linked services, triggers)  
- `warehouse/synapse_sql/` – DDL (`ddl`), transforms (`transforms`), analytics (`analytics`), security (`security`)  
- `tests/` – data quality SQL  
- `reports/` – screenshots + `findings.md`  
- `data/` – local scratch (not committed); real data lives in ADLS

## Prereqs
- Azure subscription with Owner/Contributor on a resource group
- **CLI:** Azure CLI, Terraform
- `az login` to authenticate

## Deploy infra (Terraform)
```bash
cd infra/terraform
# create terraform.tfvars with your values (prefix, location, sql admin, etc.)
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"