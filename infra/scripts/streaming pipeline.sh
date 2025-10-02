RG=rg-nyctaxi-stream
LOC=eastus2
ADF=adf-nyctaxi-stream

# create or noop if it exists
az datafactory create -g "$RG" -n "$ADF" -l "$LOC"

# show identity
ADF_MI=$(az datafactory show -g "$RG" -n "$ADF" --query identity.principalId -o tsv)
echo "ADF managed identity: $ADF_MI"

# Grant ADF MI read on curated storage
SA=nyctaxistreamsa001
SA_ID=$(az storage account show -g "$RG" -n "$SA" --query id -o tsv)

az role assignment create \
  --assignee-object-id "$ADF_MI" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Reader" \
  --scope "$SA_ID"


