# kube-arc-data-services-installer-job
Kubernetes job for installing Azure ARC and Azure ARC Data Services on a Kubernetes cluster.

## Environment Spinup

```bash
# ---------------------
# ENVIRONMENT VARIABLES
# For Terraform
# ---------------------
export TF_VAR_SPN_CLIENT_ID=$spnClientId
export TF_VAR_SPN_CLIENT_SECRET=$spnClientSecret
export TF_VAR_SPN_TENANT_ID=$spnTenantId
export TF_VAR_SPN_SUBSCRIPTION_ID=$subscriptionId
export TF_VAR_resource_prefix='arccicd'
export TF_VAR_tags='{ Source = "terraform", Owner = "Raki", Project = "CICD Testing for Arc" }'

cd /workspaces/kube-arc-data-services-installer-job/test/terraform

# ---------------------
# DEPLOY TERRAFORM
# ---------------------
terraform init
terraform plan
terraform apply -auto-approve

# ---------------------
# EXTRACT OUTPUTS
# ---------------------
export resourceGroup=$(terraform output --raw resource_group_name)
export aksClusterName=$(terraform output --raw aks_name)
export acrName=$(terraform output --raw acr_name)

# ---------------------
# Grab admin kubeconfig
# ---------------------
# Cluster-admin kubeconfig to start process
become_cluster_admin () {
  az login --service-principal --username $spnClientId --password $spnClientSecret --tenant $spnTenantId
  az account set --subscription $subscriptionId
  az config set extension.use_dynamic_install=yes_without_prompt
  rm $HOME/.kube/config
  az aks get-credentials --resource-group $resourceGroup --name $aksClusterName --admin
}

become_cluster_admin

kubectl get nodes
```

## Build and push image to ACR

```bash
export containerVersion='0.1.0' # To increment via CI pipeline
export containerName='kube-arc-data-services-installer-job'

az acr login --name $acrName

cd /workspaces/kube-arc-data-services-installer-job

# Remove Windows Carriage Returns
dos2unix /workspaces/kube-arc-data-services-installer-job/src/scripts/install-arc-data-services.sh

# Build & Push
docker build -t $acrName.azurecr.io/$containerName:$containerVersion .
docker push $acrName.azurecr.io/$containerName:$containerVersion
```

## Deploy manifests

```bash
# Set necessary environment variables for Job Secret
export TENANT_ID=$spnTenantId
export SUBSCRIPTION_ID=$subscriptionId
export CLIENT_ID=$spnClientId
export CLIENT_SECRET=$spnClientSecret

export CONNECTED_CLUSTER_RESOURCE_GROUP="$resourceGroup-arc"
export CONNECTED_CLUSTER_LOCATION="eastasia"
export ARC_DATA_SERVICES_RESOURCE_GROUP="$resourceGroup-arc-data"
export ARC_DATA_SERVICES_LOCATION="eastasia"

export CONNECTED_CLUSTER=$aksClusterName
export ARC_DATA_SERVICES_EXT="arc-data-bootstrapper"
export DELETE_FLAG='true'

# Apply CI Kustomize overlay
k apply -k /workspaces/kube-arc-data-services-installer-job/kustomize/overlays/ci

# Tail logs
k logs job/azure-arc-kubernetes-bootstrap -n azure-arc-kubernetes-bootstrap --follow

# Remove Job
k delete -k /workspaces/kube-arc-data-services-installer-job/kustomize/overlays/ci
```
