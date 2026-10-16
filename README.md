# Private Azure API (APIM + Functions + Terraform + GitHub Actions)

This repository deploys a private-only API platform on Azure:

- Azure API Management in **internal VNet mode** (no public gateway exposure)
- Azure Function App (PowerShell) with **public network access disabled**
- Azure Storage account (for Function runtime) with **public network access disabled**
- Private endpoints + private DNS zones so traffic stays on private network paths
- Terraform IaC for full environment provisioning
- GitHub Actions for infrastructure and function code deployment

## Architecture

- **VNet** with three subnets:
  - `snet-apim`: APIM internal mode
  - `snet-private-endpoints`: private endpoints
  - `snet-function-integration`: Function App VNet integration
- **APIM** exposes `GET /hello`, rewrites to Function endpoint `/api/hello`
- **Function App** serves a PowerShell hello-world response
- **Storage** is private-only, with private endpoints for blob/file/queue/table
- **DNS** private zones linked to VNet:
  - `privatelink.azurewebsites.net`
  - `privatelink.blob.core.windows.net`
  - `privatelink.file.core.windows.net`
  - `privatelink.queue.core.windows.net`
  - `privatelink.table.core.windows.net`
  - `azure-api.net` (A record for APIM internal gateway hostname)

## Repository Layout

- `infra/main.tf`: full infrastructure definition
- `infra/variables.tf`: Terraform input variables
- `infra/outputs.tf`: Terraform outputs
- `infra/versions.tf`: Terraform and provider requirements
- `infra/terraform.tfvars.example`: example Terraform values
- `infra/apim/openapi.json`: APIM API definition
- `infra/apim/policy.xml`: APIM inbound policy to route to Function backend
- `src/HelloFunction/`: PowerShell Function app
- `.github/workflows/deploy-infra.yml`: IaC deployment workflow
- `.github/workflows/deploy-function.yml`: Function code deployment workflow

## Prerequisites

1. Azure subscription.
2. GitHub repository configured with OIDC federation to Azure AD app/service principal.
3. Terraform remote state storage account and container.
   - You can reuse your existing storage account.
4. **Self-hosted GitHub Actions runner inside the target VNet** (or with private DNS/VNet connectivity).
   - Required because Function App has public access disabled and deployment uses private path.
5. APIM publisher values.

## GitHub Configuration

### Repository secrets

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

### Repository variables

- `AZURE_RESOURCE_GROUP`
- `AZURE_LOCATION` (for example `eastus`)
- `WORKLOAD_NAME` (for example `azureapi`)
- `APIM_PUBLISHER_EMAIL`
- `APIM_PUBLISHER_NAME`
- `TFSTATE_RESOURCE_GROUP`
- `TFSTATE_STORAGE_ACCOUNT`
- `TFSTATE_CONTAINER` (for example `tfstate`)
- `TFSTATE_KEY` (for example `azureapi-prod.tfstate`)

## Deploy

1. Run workflow **Deploy Azure Infrastructure**.
2. Run workflow **Deploy Function Code**.

You can also let pushes to `main` trigger these workflows automatically when relevant paths change.

## Validate from inside the VNet

From a VM or runner that uses the same VNet/private DNS:

```powershell
Invoke-RestMethod -Method Get -Uri "https://<apim-name>.azure-api.net/hello"
```

Expected response:

```json
{
  "message": "hello from private function",
  "utcTime": "..."
}
```

## Notes

- `Developer` APIM SKU is used by default for lower cost. For production SLA and scale, use `Premium`.
- Deployments are private-by-design. Calls from public internet should not resolve/reach this API gateway.
- Terraform state is remote in Azure Storage; keep it in a dedicated container.
