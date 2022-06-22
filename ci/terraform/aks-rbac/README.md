# AKS RBAC example

This folder contains a [Terraform](https://www.terraform.io/) configuration that uses the [modules hosted here](https://github.com/KangarooKube/terraform-infrastructure-modules) to deploy:
 * AKS cluster with RBAC and Audit Logging enabled
 * Standalone ACR for installer image pushes

## Pre-requisites

* Launch this `.devcontainer`
* You must have an Azure Service Principal with `Contributor` priveleges injected into this container.

Please note that this code was written for Terraform 1.x+.

## Manual run

Change directory to here:
```bash
cd /workspaces/kube-arc-data-services-installer-job/ci/terraform/aks-rbac
```

Pipe in Service Principal Creds from environment variables:

```bash
# Terraform Provider
export ARM_TENANT_ID=$spnTenantId
export ARM_CLIENT_ID=$spnClientId
export ARM_CLIENT_SECRET=$spnClientSecret
export ARM_SUBSCRIPTION_ID=$subscriptionId

# Golang Azure SDK
export AZURE_TENANT_ID=$ARM_TENANT_ID
export AZURE_CLIENT_ID=$ARM_CLIENT_ID
export AZURE_CLIENT_SECRET=$ARM_CLIENT_SECRET
export AZURE_SUBSCRIPTION_ID=$ARM_SUBSCRIPTION_ID
```

Configure module specific variables:

```bash
export TF_VAR_resource_prefix='8479q7h' # Replace the number with something random!
export TF_VAR_location='canadacentral'
export TF_VAR_tags='{ Source = "terraform", Owner = "Your Name", Project = "Messing around with terraform manually" }'
```

Configure Azure Storage Account Backend State info before running `init`:

```bash
export stateFileKeyName="kube-arc-data-services-installer-job/${TF_VAR_resource_prefix}/terraform.tfstate"
export TF_CLI_ARGS_init="-backend-config='storage_account_name=${TFSTATE_STORAGE_ACCOUNT_NAME}'"
export TF_CLI_ARGS_init="$TF_CLI_ARGS_init -backend-config='container_name=${TFSTATE_STORAGE_ACCOUNT_CONTAINER_NAME}'"
export TF_CLI_ARGS_init="$TF_CLI_ARGS_init -backend-config='access_key=${TFSTATE_STORAGE_ACCOUNT_KEY}'"
export TF_CLI_ARGS_init="$TF_CLI_ARGS_init -backend-config='key=${stateFileKeyName}'"
```

Deploy the code:

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

Grab outputs:

```bash
export acrName=$(terraform output --raw acr_name)
```

Test kubernetes access:

```bash
export KUBECONFIG='./kubeconfig'
kubectl get nodes
```

Build and push docker image:

```bash
export containerVersion='0.1.0' # To increment via CI pipeline
export containerName='kube-arc-data-services-installer-job'

# Remove Windows Carriage Returns
dos2unix /workspaces/kube-arc-data-services-installer-job/src/scripts/install-arc-data-services.sh

# Build & Push
cd /workspaces/kube-arc-data-services-installer-job
docker login $acrName.azurecr.io -u $spnClientId -p $spnClientSecret
docker build -t $acrName.azurecr.io/$containerName:$containerVersion .
docker push $acrName.azurecr.io/$containerName:$containerVersion
```

Follow the steps in the [README](../../../README.md#deploy-manifest) to deploy the manifest.

Clean up when you're done:

```
terraform destroy -auto-approve
rm -rf .terraform
rm .terraform.lock.hcl
```