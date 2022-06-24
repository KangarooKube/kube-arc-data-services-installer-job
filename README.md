# kube-arc-data-services-installer-job
Kubernetes job for installing Azure ARC and Azure ARC Data Services on a Kubernetes cluster.

| Tested on AKS and OpenShift 4.10.16

## Environment spinup

You will need:
* A Kubernetes Cluster
* A Container Registry to build and push images to

Follow the steps [here](ci/terraform/aks-rbac/README.md) to deploy an environment using Terraform, the same environment our CI runs use.

## Deploy manifests

### Update image tag from env variable via `envsubst`

```bash
export IMAGE_REGISTRY="${acrName}.azurecr.io"
export IMAGE_TAG="${containerVersion}"
export BASE_PATH="/workspaces/kube-arc-data-services-installer-job/kustomize/base"

envsubst \
    < $BASE_PATH/kustomization.template.yaml \
    > $BASE_PATH/kustomization.yaml
```

### Variables for `ConfigMap` and `Secret`

Same set works for AKS and OpenShift - kustomize overlay contains the differences:
```bash
export resourceGroup='arcjob-rg'                              # Prefix to append to the two RGs below
export clusterName='arc-k8s'                                  # Can be anything
# Secret
export TENANT_ID=$SPN_TENANT_ID                                 # Passed into Job to authenticate to Azure to create resources
export SUBSCRIPTION_ID=$SPN_SUBSCRIPTION_ID
export CLIENT_ID=$SPN_CLIENT_ID
export CLIENT_SECRET=$SPN_CLIENT_SECRET
export AZDATA_USERNAME='boor'
export AZDATA_PASSWORD='acntorPRESTO!'
# ConfigMap
export CONNECTED_CLUSTER_RESOURCE_GROUP="$resourceGroup-arc"
export CONNECTED_CLUSTER_LOCATION="eastasia"                  # Where Arc Connected Cluster RG will be created
export ARC_DATA_RESOURCE_GROUP="$resourceGroup-arc-data"
export ARC_DATA_LOCATION="eastasia"                           # Where Arc Data RG will be created - can be different from Connected Cluster
export CONNECTED_CLUSTER=$clusterName
export ARC_DATA_EXT="arc-data-bootstrapper"
export ARC_DATA_EXT_AUTO_UPGRADE="false"
export ARC_DATA_EXT_VERSION="1.2.19831003"                    # Can update per release to test
export ARC_DATA_NAMESPACE="azure-arc-data"
export ARC_DATA_CONTROLLER="azure-arc-data-controller"
export ARC_DATA_CONTROLLER_LOCATION="southeastasia"           # Based on RP availability
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
  az login --service-principal --username $SPN_CLIENT_ID --password $SPN_CLIENT_SECRET --tenant $SPN_TENANT_ID
  az account set --subscription $SPN_SUBSCRIPTION_ID
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