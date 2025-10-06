# Developer Setup Guide

## Prerequisites
- Azure CLI 2.50+
- Terraform 1.5+
- Bicep CLI
- Python 3.9+
- VS Code with extensions: Azure, Terraform, SQL

## Local Development
```bash
# Setup Python environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt

# Configure Azure CLI
az login
az account set --subscription "YOUR_SUB_ID"

# Initialize Terraform
cd infra/terraform
terraform init