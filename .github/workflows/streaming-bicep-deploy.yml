name: streaming-bicep-deploy

on:
  push:
    branches: [ main ]
    paths:
      - 'infra/streaming-bicep/**'
      - '.github/workflows/streaming-bicep-deploy.yml'
  workflow_dispatch:

env:
  RESOURCE_GROUP: rg-nyctaxi-stream
  LOCATION: eastus2
  TEMPLATE_FILE: infra/streaming-bicep/main.bicep
  PARAM_FILE: infra/streaming-bicep/params.dev.json
  ASA_JOB_NAME: asa-nyctaxi-trip
  DATA_LOCALE: en-US
  LATE_SECONDS: 900
  COMPAT_LEVEL: "1.2"
  # expose subscription id for REST calls and az cli
  SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

concurrency:
  group: streaming-bicep-deploy
  cancel-in-progress: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    environment: streaming-dev

    steps:
      - uses: actions/checkout@v4

      - name: Azure login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Who am I (debug)
        uses: azure/cli@v2
        with:
          inlineScript: |
            az account show -o table

      - name: Ensure RG exists
        uses: azure/cli@v2
        with:
          inlineScript: |
            az group create -n "$RESOURCE_GROUP" -l "$LOCATION" -o none

      # If the job exists from a previous run, delete it so the create is clean
      - name: Delete existing ASA job if present
        uses: azure/cli@v2
        with:
          inlineScript: |
            set -euo pipefail
            if az resource show -g "$RESOURCE_GROUP" -n "$ASA_JOB_NAME" --resource-type Microsoft.StreamAnalytics/streamingjobs >/dev/null 2>&1; then
              echo "Existing ASA job found; deleting..."
              az resource delete -g "$RESOURCE_GROUP" -n "$ASA_JOB_NAME" --resource-type Microsoft.StreamAnalytics/streamingjobs
              for i in {1..30}; do
                if az resource show -g "$RESOURCE_GROUP" -n "$ASA_JOB_NAME" --resource-type Microsoft.StreamAnalytics/streamingjobs >/dev/null 2>&1; then
                  echo "Waiting for deletion... ($i)"; sleep 5
                else
                  echo "ASA job deleted."; break
                fi
              done
            else
              echo "No existing ASA job."
            fi

      # Create ASA job via ARM REST (api-version 2021-10-01-preview)
      - name: Create ASA job (REST)
        uses: azure/cli@v2
        with:
          inlineScript: |
            set -euo pipefail

            URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.StreamAnalytics/streamingjobs/$ASA_JOB_NAME?api-version=2021-10-01-preview"

            cat >/tmp/asa-job.json <<EOF
            {
              "location": "$LOCATION",
              "identity": { "type": "SystemAssigned" },
              "sku": { "name": "Standard" },
              "properties": {
                "jobType": "Cloud",
                "eventsOutOfOrderPolicy": "Adjust",
                "eventsOutOfOrderMaxDelayInSeconds": $LATE_SECONDS,
                "eventsLateArrivalMaxDelayInSeconds": $LATE_SECONDS,
                "dataLocale": "$DATA_LOCALE",
                "outputErrorPolicy": "Stop",
                "compatibilityLevel": "$COMPAT_LEVEL"
              }
            }
            EOF

            echo "Creating ASA job $ASA_JOB_NAME ..."
            az rest --method put --uri "$URI" --body @/tmp/asa-job.json --only-show-errors -o none
            echo "ASA job created."

      # Wait for the system-assigned identity to be ready so RBAC in Bicep succeeds
      - name: Wait for ASA managed identity (principalId)
        uses: azure/cli@v2
        with:
          inlineScript: |
            set -euo pipefail
            for i in {1..30}; do
              PID=$(az resource show \
                -g "$RESOURCE_GROUP" \
                -n "$ASA_JOB_NAME" \
                --resource-type Microsoft.StreamAnalytics/streamingjobs \
                --query "identity.principalId" -o tsv || true)
              if [ -n "$PID" ] && [ "$PID" != "None" ]; then
                echo "principalId ready: $PID"; break
              fi
              echo "Waiting for principalId... ($i)"; sleep 5
            done

      # Deploy with AZ CLI (avoid azure/arm-deploy validation bug)
      - name: Deploy Bicep (az cli)
        uses: azure/cli@v2
        with:
          inlineScript: |
            set -euo pipefail
            az deployment group create \
              --resource-group "$RESOURCE_GROUP" \
              --name "stream-deploy-${GITHUB_RUN_ID}" \
              --template-file "$TEMPLATE_FILE" \
              --parameters @"$PARAM_FILE" \
              --mode Incremental \
              --only-show-errors

      # Optional: stop ASA job after deploy to avoid runtime costs
      - name: Stop ASA job (cost-safe)
        uses: azure/cli@v2
        with:
          inlineScript: |
            set -euo pipefail
            az rest --method post \
              --uri "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.StreamAnalytics/streamingjobs/$ASA_JOB_NAME/stop?api-version=2021-10-01-preview" \
              -o none || true
