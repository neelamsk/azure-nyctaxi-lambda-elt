# Project Structure Guide

## 📁 Directory Overview

| Directory | Purpose | Key Files |
|-----------|---------|-----------|
| `/infra` | Infrastructure as Code | Terraform for batch, Bicep for streaming |
| `/orchestration` | Pipeline definitions | ADF pipelines, Synapse notebooks |
| `/sql` | Database objects | DDL, stored procedures, views |
| `/docs/img` | Architecture & screenshots | Lineage, monitoring, dashboards |
| `/tools` | Utilities | Event producer for testing |
| `/.github` | CI/CD workflows | Terraform plan/apply, Bicep deploy |

## 🏗 Architecture Decisions
- **Dual IaC**: Terraform for stable batch infrastructure, Bicep for Azure-native streaming
- **Medallion**: Raw → Staging → Core → Model (mdl)
- **Lambda**: Parallel batch and streaming paths converging in model layer