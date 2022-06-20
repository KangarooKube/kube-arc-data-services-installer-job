# kube-arc-data-services-installer-job
Kubernetes job for installing Azure ARC and Azure ARC Data Services on a Kubernetes cluster.

| Tested on AKS and OpenShift 4.10.16

## AKS Environment spinup
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
```

> OpenShift Env setup TBD.

## Build and push image to ACR

```bash
# ---------------------
# EXTRACT OUTPUTS
# ---------------------
export resourceGroup=$(terraform output --raw resource_group_name)
export aksClusterName=$(terraform output --raw aks_name)
export acrName=$(terraform output --raw acr_name)

export containerVersion='0.1.0' # To increment via CI pipeline
export containerName='kube-arc-data-services-installer-job'

cd /workspaces/kube-arc-data-services-installer-job

# Remove Windows Carriage Returns
dos2unix /workspaces/kube-arc-data-services-installer-job/src/scripts/install-arc-data-services.sh

# Build & Push
az acr login --name $acrName
docker build -t $acrName.azurecr.io/$containerName:$containerVersion .
docker push $acrName.azurecr.io/$containerName:$containerVersion
```

## Deploy manifests

### Variables for `ConfigMap` and `Secret`

Same set works for AKS and OpenShift - kustomize overlay contains the differences:
```bash
export resourceGroup='arcjob-rg'
export clusterName='arc-k8s'
# Secret
export TENANT_ID=$spnTenantId
export SUBSCRIPTION_ID=$subscriptionId
export CLIENT_ID=$spnClientId
export CLIENT_SECRET=$spnClientSecret
export AZDATA_USERNAME='boor'
export AZDATA_PASSWORD='acntorPRESTO!'
# ConfigMap
export CONNECTED_CLUSTER_RESOURCE_GROUP="$resourceGroup-arc"
export CONNECTED_CLUSTER_LOCATION="eastasia"
export ARC_DATA_RESOURCE_GROUP="$resourceGroup-arc-data"
export ARC_DATA_LOCATION="eastasia"
export CONNECTED_CLUSTER=$clusterName
export ARC_DATA_EXT="arc-data-bootstrapper"
export ARC_DATA_EXT_AUTO_UPGRADE="false"
export ARC_DATA_EXT_VERSION="1.2.19831003"
export ARC_DATA_NAMESPACE="azure-arc-data"
export ARC_DATA_CONTROLLER="azure-arc-data-controller"
export ARC_DATA_CONTROLLER_LOCATION="southeastasia"
# false = onboard Arc
# delete = destroy Arc
# Both are idempotent
export DELETE_FLAG='false'
```

### AKS
#### Setup
```bash
# ---------------------
# Grab admin kubeconfig
# ---------------------
# Cluster-admin kubeconfig to start process
become_aks_cluster_admin () {
  az login --service-principal --username $spnClientId --password $spnClientSecret --tenant $spnTenantId
  az account set --subscription $subscriptionId
  az config set extension.use_dynamic_install=yes_without_prompt
  rm $HOME/.kube/config
  az aks get-credentials --resource-group $resourceGroup --name $aksClusterName --admin
}

become_aks_cluster_admin
```

#### Deploy

```bash
# Apply CI Kustomize overlay
k apply -k /workspaces/kube-arc-data-services-installer-job/kustomize/overlays/aks

# Tail logs
k logs job/azure-arc-kubernetes-bootstrap -n azure-arc-kubernetes-bootstrap --follow

# Remove Job
k delete -k /workspaces/kube-arc-data-services-installer-job/kustomize/overlays/aks
```

### OpenShift

#### Setup
```bash
become_ocp_cluster_admin () {
  export OCP_KUBECONFIG=/workspaces/kube-arc-data-services-installer-job/.devcontainer/kubeconfig
  rm $HOME/.kube/config
  cp $OCP_KUBECONFIG $HOME/.kube/config

  # DNS hack specific to my environment
  cat << EOF > /etc/resolv.conf
# DNS requests are forwarded to the host. DHCP DNS options are ignored.
nameserver 10.216.175.4                 # OCPLab-DC.fg.contoso.com
EOF
}

become_ocp_cluster_admin
```

#### Deploy

```bash
# Apply CI Kustomize overlay
k apply -k /workspaces/kube-arc-data-services-installer-job/kustomize/overlays/ocp

# Tail logs
k logs job/azure-arc-kubernetes-bootstrap -n azure-arc-kubernetes-bootstrap --follow

# Remove Job
k delete -k /workspaces/kube-arc-data-services-installer-job/kustomize/overlays/ocp
```