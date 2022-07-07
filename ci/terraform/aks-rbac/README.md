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
export ARM_TENANT_ID=$SPN_TENANT_ID
export ARM_CLIENT_ID=$SPN_CLIENT_ID
export ARM_CLIENT_SECRET=$SPN_CLIENT_SECRET
export ARM_SUBSCRIPTION_ID=$SPN_SUBSCRIPTION_ID

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
docker login $acrName.azurecr.io -u $SPN_CLIENT_ID -p $SPN_CLIENT_SECRET

# Read in environment variables for --build-args
source /workspaces/kube-arc-data-services-installer-job/release/release.env

# Build via env variables
docker build -t $acrName.azurecr.io/$containerName:$containerVersion \
    --build-arg HELM_VERSION=${HELM_VERSION} \
    --build-arg KUBECTL_VERSION=${KUBECTL_VERSION} \
    --build-arg AZCLI_VERSION=${AZCLI_VERSION} \
    --build-arg EXT_K8S_CONFIGURATION_VERSION=${EXT_K8S_CONFIGURATION_VERSION} \
    --build-arg EXT_ARCDATA_VERSION=${EXT_ARCDATA_VERSION} \
    --build-arg EXT_K8S_EXTENSION_VERSION=${EXT_K8S_EXTENSION_VERSION} \
    --build-arg EXT_K8S_CONNECTEDK8S_VERSION=${EXT_K8S_CONNECTEDK8S_VERSION} \
    --build-arg EXT_K8S_CUSTOMLOCATION_VERSION=${EXT_K8S_CUSTOMLOCATION_VERSION} \
    --build-arg ARC_DATA_EXT_VERSION=${ARC_DATA_EXT_VERSION} \
    --build-arg ARC_DATA_CONTROLLER_VERSION=${ARC_DATA_CONTROLLER_VERSION} \
    .

# Push to ACR
docker push $acrName.azurecr.io/$containerName:$containerVersion
```

Follow the steps in the [README](../../../README.md#deploy-manifest) to deploy the manifest.

Clean up when you're done:

```
terraform destroy -auto-approve
rm -rf .terraform
rm .terraform.lock.hcl
```