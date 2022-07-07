#!/bin/bash
set -e -o pipefail

cat << EOF

Copyright (c) 2022 KangarooKube

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
----------------------------------------------------------------------------------

EOF

# ================
# Input Validation
# ================

if [[ -z "${VERBOSE}" ]]; then
  echo "INFO | Verbose flag not set, defaulting to true"
  export VERBOSE=1
else 
  echo "INFO | Verbose flag set to ${VERBOSE}"
  if [ "${VERBOSE}" = 'true' ]; then
    export VERBOSE=1
  else
    unset VERBOSE
    az config set core.only_show_errors=true --only-show-errors
  fi
fi

# Docker release.env variables
bootstrapper_version_param=()
if [[ -z "${ARC_DATA_EXT_VERSION}" ]]; then
  echo "ERROR | variable ARC_DATA_EXT_VERSION is required for onboarding with this image at this time, please pass in through container image's release.env"
  exit 1
else
  bootstrapper_version_param+=(--version "${ARC_DATA_EXT_VERSION}")
  # Check if auto upgrade is set to true
  if [ "${ARC_DATA_EXT_AUTO_UPGRADE}" = 'true' ]; then
    echo "INFO | variable ARC_DATA_EXT_AUTO_UPGRADE is set to true even though ARC_DATA_EXT_VERSION is specified, forcing false"
  fi
  # Because bootstrapper version is set, Auto Upgrade must be off, else CLI will error
  export ARC_DATA_EXT_AUTO_UPGRADE='false'
fi

# Controller image validation
if [[ -z "${ARC_DATA_CONTROLLER_VERSION}" ]]; then
  echo "ERROR | variable ARC_DATA_CONTROLLER_VERSION is required for onboarding, please pass in through container image's release.env."
  exit 1
fi

# Compare .spec.docker.imageTag in control.json with container environment variable
ARC_DATA_CONTROLLER_VERSION_CONTROL_JSON=$(cat "./custom/control.json" | jq -r .spec.docker.imageTag)

if [[ "${ARC_DATA_CONTROLLER_VERSION}" != "${ARC_DATA_CONTROLLER_VERSION_CONTROL_JSON}" ]]; then
  echo "ERROR | variable ARC_DATA_CONTROLLER_VERSION = '${ARC_DATA_CONTROLLER_VERSION}' does not match control.json's spec.docker.imageTag = '${ARC_DATA_CONTROLLER_VERSION_CONTROL_JSON}', something went wrong in the release or you applied an incorrect manifest for this release."
  exit 1
fi

echo ""
echo "INFO | Onboarding to Bootstrapper version: ${ARC_DATA_EXT_VERSION}"
echo "INFO | Onboarding to Data Controller version: ${ARC_DATA_CONTROLLER_VERSION}"
echo ""

# K8s Configmap variables
if [[ -z "${DELETE_FLAG}" ]]; then
  echo "INFO | DELETE_FLAG is not set, defaulting to false"
  export DELETE_FLAG='false'
fi

if [[ -z "${OPENSHIFT}" ]]; then
  echo "INFO | OPENSHIFT is not set, defaulting to false"
  export OPENSHIFT='false'
fi

if [ "${OPENSHIFT}" = 'true' ]; then
  echo "INFO | Onboarding will run in context for OpenShift"
fi

if [ "${DELETE_FLAG}" = 'false' ]; then
  echo "INFO | Starting Arc + Data Services onboarding process"
fi

if [[ -z "${CONNECTED_CLUSTER_LOCATION}" ]]; then
    echo "ERROR | variable CONNECTED_CLUSTER_LOCATION is required"
    exit 1
fi

if [[ -z "${TENANT_ID}" ]]; then
  echo "ERROR | variable TENANT_ID is required."
  exit 1
fi

if [[ -z "${SUBSCRIPTION_ID}" ]]; then
  echo "ERROR | variable SUBSCRIPTION_ID is required."
  exit 1
fi

if [[ -z "${CLIENT_ID}" ]]; then
  echo "ERROR | variable CLIENT_ID is required."
  exit 1
fi

if [[ -z "${CLIENT_SECRET}" ]]; then
  echo "ERROR | variable CLIENT_SECRET is required."
  exit 1
fi

if [[ -z "${CONNECTED_CLUSTER_RESOURCE_GROUP}" ]]; then
  echo "ERROR | variable CONNECTED_CLUSTER_RESOURCE_GROUP is required."
  exit 1
fi

if [[ -z "${CONNECTED_CLUSTER}" ]]; then
  echo "ERROR | variable CONNECTED_CLUSTER is required."
  exit 1
fi

if [[ -z "${ARC_DATA_RESOURCE_GROUP}" ]]; then
  echo "ERROR | variable ARC_DATA_RESOURCE_GROUP is required."
  exit 1
fi

if [[ -z "${ARC_DATA_RESOURCE_GROUP}" ]]; then
  echo "ERROR | variable ARC_DATA_RESOURCE_GROUP is required."
  exit 1
fi

if [[ -z "${ARC_DATA_LOCATION}" ]]; then
  echo "INFO | variable ARC_DATA_LOCATION is not set, defaulting to CONNECTED_CLUSTER_LOCATION"
  ARC_DATA_LOCATION=${CONNECTED_CLUSTER_LOCATION}
  export ARC_DATA_LOCATION
fi

if [[ -z "${ARC_DATA_CONTROLLER_LOCATION}" ]]; then
  echo "INFO | variable ARC_DATA_CONTROLLER_LOCATION is not set, defaulting to ARC_DATA_LOCATION"
  ARC_DATA_CONTROLLER_LOCATION=${ARC_DATA_LOCATION}
  export ARC_DATA_CONTROLLER_LOCATION
fi

if [[ -z "${ARC_DATA_EXT}" ]]; then
  echo "INFO | variable ARC_DATA_EXT is not set, defaulting to arc-data-bootstrapper"
  ARC_DATA_EXT='arc-data-bootstrapper'
  export ARC_DATA_EXT
fi

if [[ -z "${ARC_DATA_NAMESPACE}" ]]; then
  echo "ERROR | variable ARC_DATA_NAMESPACE is required."
  exit 1
fi

if [[ -z "${ARC_DATA_CONTROLLER}" ]]; then
  echo "ERROR | variable ARC_DATA_CONTROLLER is required."
  exit 1
fi

if [[ -z "${AZDATA_USERNAME}" ]]; then
  echo "ERROR | variable AZDATA_USERNAME is required."
  exit 1
else
  echo "INFO | variable AZDATA_USERNAME is set, also defaulting AZDATA_LOGSUI_USERNAME and AZDATA_METRICSUI_USERNAME"
  AZDATA_LOGSUI_USERNAME=${AZDATA_USERNAME}
  AZDATA_METRICSUI_USERNAME=${AZDATA_USERNAME}
  export AZDATA_LOGSUI_USERNAME
  export AZDATA_METRICSUI_USERNAME
fi

if [[ -z "${AZDATA_PASSWORD}" ]]; then
  echo "ERROR | variable AZDATA_PASSWORD is required."
  exit 1
else
  echo "INFO | variable AZDATA_PASSWORD is set, also defaulting AZDATA_LOGSUI_PASSWORD and AZDATA_METRICSUI_PASSWORD"
  AZDATA_LOGSUI_PASSWORD=${AZDATA_PASSWORD}
  AZDATA_METRICSUI_PASSWORD=${AZDATA_PASSWORD}
  export AZDATA_LOGSUI_PASSWORD
  export AZDATA_METRICSUI_PASSWORD
fi

custom_location_oid_param=()
if [[ -n "${CUSTOM_LOCATION_OID}" ]]; then
  custom_location_oid_param+=(--custom-locations-oid "${CUSTOM_LOCATION_OID}")
fi

timeout_param=()
if [[ -n "${ONBOARDING_TIMEOUT}" ]]; then
  timeout_param+=(--onboarding-timeout "${ONBOARDING_TIMEOUT}")
fi

# ==========================
# Authenticate to API Server
# ==========================

APISERVER=https://kubernetes.default.svc/
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt > ca.crt

kubectl config set-cluster azure-arc-kubernetes-bootstrap \
  --embed-certs=true \
  --server="${APISERVER}" \
  --certificate-authority=./ca.crt

kubectl config set-credentials azure-arc-kubernetes-bootstrap --token="${TOKEN}"

kubectl config set-context azure-arc-kubernetes-bootstrap \
  --cluster=azure-arc-kubernetes-bootstrap \
  --user=azure-arc-kubernetes-bootstrap \
  --namespace=default

kubectl config use-context azure-arc-kubernetes-bootstrap

echo ""
echo "INFO | Running on following cluster:"
kubectl cluster-info 
echo ""
echo "INFO | Using following config:"
kubectl config view
echo ""

# =====================
# Authenticate to Azure
# =====================

echo ""
echo "INFO | Azure CLI versions:"
az -v
echo ""

echo "INFO | Logging into Azure:"
echo ""

az login --service-principal \
          -u "${CLIENT_ID}" \
          -p "${CLIENT_SECRET}" \
          --tenant "${TENANT_ID}" \
          --query "[].{\"Available Subscriptions\":name}" \
          --output table

az account set --subscription "${SUBSCRIPTION_ID}"

AZ_CURRENT_ACCOUNT=$(az account show --query "name" --output tsv)
export AZ_CURRENT_ACCOUNT

echo ""
echo "INFO | Current subscription assigned $AZ_CURRENT_ACCOUNT"

# ====================
# Central Status Check
# ====================
# .
# └── 1. Connected Cluster and Data Services RG
#     └── 2. Connected Cluster
#         ├── 2a. Idempotent - Enable Cluster-Connect and Custom-Locations
#         ├── 3. Bootstrapper Extension
#         |   └── 3a. Idempotent - Bootstrapper MSI Assignment
#         └── 4. Custom Location
#             └── 5. Data Controller

# 1. Connected Cluster and Data Services RG
CONNECTED_CLUSTER_RESOURCE_GROUP_EXISTS=$(az group list | jq -r ".[] | select(.name==\"$CONNECTED_CLUSTER_RESOURCE_GROUP\") |.name")
export CONNECTED_CLUSTER_RESOURCE_GROUP_EXISTS
ARC_DATA_RESOURCE_GROUP_EXISTS=$(az group list | jq -r ".[] | select(.name==\"$ARC_DATA_RESOURCE_GROUP\") |.name")
export ARC_DATA_RESOURCE_GROUP_EXISTS

# 1. Check dependents:
if [[ -n "${CONNECTED_CLUSTER_RESOURCE_GROUP_EXISTS}" ]] && [[ -n "${ARC_DATA_RESOURCE_GROUP_EXISTS}" ]]; then
  
  # 2. Connected Cluster
  CONNECTED_CLUSTER_EXISTS=$(az resource list --name "$CONNECTED_CLUSTER" --resource-group "$CONNECTED_CLUSTER_RESOURCE_GROUP" --query "[?contains(type,'Microsoft.Kubernetes/connectedClusters')].name" --output tsv)
  export CONNECTED_CLUSTER_EXISTS

  if [[ -n "${CONNECTED_CLUSTER_EXISTS}" ]]; then

    # 3. Bootstrapper Extension
    ARC_DATA_EXT_EXISTS=$(az k8s-extension list --cluster-name "$CONNECTED_CLUSTER" --resource-group "$CONNECTED_CLUSTER_RESOURCE_GROUP" --cluster-type connectedclusters | jq -r ".[] | select(.extensionType==\"microsoft.arcdataservices\") |.name")
    export ARC_DATA_EXT_EXISTS

    # 4. Custom Location
    ARC_DATA_CUSTOM_LOCATION_EXISTS=$(az resource list --name "${ARC_DATA_NAMESPACE}" --resource-group "${ARC_DATA_RESOURCE_GROUP}" --query "[?contains(type,'Microsoft.ExtendedLocation/customLocations')].name" --output tsv)
    export ARC_DATA_CUSTOM_LOCATION_EXISTS

      # 5. Data Controller
      if [[ -n "${ARC_DATA_CUSTOM_LOCATION_EXISTS}" ]]; then
        ARC_DATA_CONTROLLER_EXISTS=$(az resource list --name "$ARC_DATA_CONTROLLER" --resource-group "$ARC_DATA_RESOURCE_GROUP" --query "[?contains(type,'Microsoft.AzureArcData/DataControllers')].name" --output tsv)
        export ARC_DATA_CONTROLLER_EXISTS
      fi
  fi

fi

function true_if_nonempty {
  if [ -z "$1" ]; then
    echo "false"
  else
    echo "true"
  fi
}

# Update to 'true' or 'false' rather than empty and non-empty
CONNECTED_CLUSTER_RESOURCE_GROUP_EXISTS=$(true_if_nonempty "${CONNECTED_CLUSTER_RESOURCE_GROUP_EXISTS}")
ARC_DATA_RESOURCE_GROUP_EXISTS=$(true_if_nonempty "${ARC_DATA_RESOURCE_GROUP_EXISTS}")
CONNECTED_CLUSTER_EXISTS=$(true_if_nonempty "${CONNECTED_CLUSTER_EXISTS}")
ARC_DATA_EXT_EXISTS=$(true_if_nonempty "${ARC_DATA_EXT_EXISTS}")
ARC_DATA_CUSTOM_LOCATION_EXISTS=$(true_if_nonempty "${ARC_DATA_CUSTOM_LOCATION_EXISTS}")
ARC_DATA_CONTROLLER_EXISTS=$(true_if_nonempty "${ARC_DATA_CONTROLLER_EXISTS}")

echo ""
echo "INFO | 1. CONNECTED_CLUSTER_RESOURCE_GROUP_EXISTS? $CONNECTED_CLUSTER_RESOURCE_GROUP_EXISTS"
echo "INFO | 1. ARC_DATA_RESOURCE_GROUP_EXISTS? $ARC_DATA_RESOURCE_GROUP_EXISTS"
echo "INFO |  2. CONNECTED_CLUSTER_EXISTS? $CONNECTED_CLUSTER_EXISTS"
echo "INFO |    3. ARC_DATA_EXT_EXISTS? $ARC_DATA_EXT_EXISTS"
echo "INFO |    4. ARC_DATA_CUSTOM_LOCATION_EXISTS? $ARC_DATA_CUSTOM_LOCATION_EXISTS"
echo "INFO |      5. ARC_DATA_CONTROLLER_EXISTS? $ARC_DATA_CONTROLLER_EXISTS"
echo ""

# ======================
# Handle delete and exit
# ======================
if [ "${DELETE_FLAG}" = 'true' ]; then
  echo "INFO | Starting Arc + Data Services destruction process"
  
  # 5. Data Controller
  if [ "$ARC_DATA_CONTROLLER_EXISTS" = 'true' ]; then 
    echo "INFO | Deleting Data Controller $ARC_DATA_CONTROLLER"
    az arcdata dc delete --name "${ARC_DATA_CONTROLLER}" \
                         --subscription "${SUBSCRIPTION_ID}" \
                         --resource-group "${ARC_DATA_RESOURCE_GROUP}" \
                         --yes \
                         ${VERBOSE:+--debug --verbose}
  else 
    echo "INFO | Data Controller $ARC_DATA_CONTROLLER doest not exist, skipping delete"
  fi

  # 4. Custom Location
  if [ "$ARC_DATA_CUSTOM_LOCATION_EXISTS" = 'true' ]; then 
    echo "INFO | Deleting Custom Location $ARC_DATA_NAMESPACE"
    az customlocation delete --name "${ARC_DATA_NAMESPACE}" \
                         --resource-group "${ARC_DATA_RESOURCE_GROUP}" \
                         --yes \
                         ${VERBOSE:+--debug --verbose}
  else 
    echo "INFO | Custom Location $ARC_DATA_NAMESPACE doest not exist, skipping delete"
  fi

  # 3. Bootstrapper Extension
  if [ "$ARC_DATA_EXT_EXISTS" = 'true' ]; then 
    echo "INFO | Deleting Bootstrapper Extension $ARC_DATA_EXT"
    az k8s-extension delete --name "${ARC_DATA_EXT}" \
                        --cluster-type connectedClusters \
                        --cluster-name "${CONNECTED_CLUSTER}" \
                        --resource-group "${CONNECTED_CLUSTER_RESOURCE_GROUP}" \
                        --yes \
                        ${VERBOSE:+--debug --verbose}
    
    # Delete Arcdata CRDs
    echo "INFO | Deleting Arc Data CRDs"
    kubectl delete crd $(kubectl get crd | grep arcdata | cut -f1 -d' ') --ignore-not-found=true

    # Delete Arcdata mutatingwebhookconfiguration
    echo "INFO | Deleting Arc Data Mutating Webhook Configs"
    kubectl delete mutatingwebhookconfiguration arcdata.microsoft.com-webhook-"${ARC_DATA_NAMESPACE}" --ignore-not-found=true

  else 
    echo "INFO | Bootstrapper Extension $ARC_DATA_EXT doest not exist, skipping delete"
  fi

  # 2. Connected Cluster
  if [ "$CONNECTED_CLUSTER_EXISTS" = 'true' ]; then 
    echo "INFO | Deleting Connected Cluster $CONNECTED_CLUSTER"
      az connectedk8s delete --name "${CONNECTED_CLUSTER}" \
                             --resource-group "${CONNECTED_CLUSTER_RESOURCE_GROUP}" \
                             --yes \
                             ${VERBOSE:+--debug --verbose}
  else 
    echo "INFO | Connected Cluster $CONNECTED_CLUSTER doest not exist, skipping delete"
  fi

  # 1. Connected Cluster and Data Services RG
  if [ "$ARC_DATA_RESOURCE_GROUP_EXISTS" = 'true' ]; then 
    echo "INFO | Deleting Arc Data Services Resource Group $ARC_DATA_RESOURCE_GROUP"
      az group delete --resource-group "$ARC_DATA_RESOURCE_GROUP" \
                      --yes \
                      ${VERBOSE:+--debug --verbose}
  else 
    echo "INFO | Arc Data Services Resource Group $ARC_DATA_RESOURCE_GROUP doest not exist, skipping delete"
  fi

  if [ "$CONNECTED_CLUSTER_RESOURCE_GROUP_EXISTS" = 'true' ]; then 
    echo "INFO | Deleting Connected Cluster Resource Group $CONNECTED_CLUSTER_RESOURCE_GROUP"
      az group delete --resource-group "$CONNECTED_CLUSTER_RESOURCE_GROUP" \
                      --yes \
                      ${VERBOSE:+--debug --verbose}
  else 
    echo "INFO | Connected Cluster Resource Group $CONNECTED_CLUSTER_RESOURCE_GROUP doest not exist, skipping delete"
  fi

  # 0. Handle OpenShift pre-req cleanup
  if [ "${OPENSHIFT}" = 'true' ]; then
    echo "INFO | Removing OpenShift pre-reqs"
    kubectl delete --ignore-not-found=true -n "${ARC_DATA_NAMESPACE}" -f './openshift/arc-data-routes.yaml'
    kubectl delete --ignore-not-found=true -n "${ARC_DATA_NAMESPACE}" -f './openshift/arc-data-scc.yaml'
  fi

  echo "INFO | Deleting Arc Data Namespace"
  kubectl delete --ignore-not-found=true namespace "${ARC_DATA_NAMESPACE}"

  echo ""
  echo "----------------------------------------------------------------------------------"
  echo "INFO | Destruction complete."
  exit 0
fi

# ==========================================
# 0. Idempotent: OpenShift pre-reqs creation
# ==========================================
if [ "${OPENSHIFT}" = 'true' ]; then
  echo "INFO | Applying OpenShift pre-reqs"
  # Create namespace if not exists via apply
  kubectl create namespace "${ARC_DATA_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

  # Add annotations for Arc Data Container UID and GID and overwrite the random one OpenShift generates
  # https://cookbook.openshift.org/users-and-role-based-access-control/why-do-my-applications-run-as-a-random-user-id.html
  # https://docs.microsoft.com/en-us/azure/azure-arc/data/create-data-controller-using-kubernetes-native-tools#create-a-namespace-in-which-the-data-controller-will-be-created
  kubectl annotate namespace "${ARC_DATA_NAMESPACE}" openshift.io/sa.scc.supplemental-groups="1000700001/10000" --overwrite
  kubectl annotate namespace "${ARC_DATA_NAMESPACE}" openshift.io/sa.scc.uid-range="1000700001/10000" --overwrite

  # Create resources at namespace scope - cluster scoped resources will be created outside namespace automatically
  kubectl apply -n "${ARC_DATA_NAMESPACE}" -f './openshift/arc-data-scc.yaml'
fi

# =========================================
# 1. Connected Cluster and Data Services RG
# =========================================
if [ "$CONNECTED_CLUSTER_RESOURCE_GROUP_EXISTS" = 'true' ]; then
    echo "INFO | Connected Cluster Resource Group $CONNECTED_CLUSTER_RESOURCE_GROUP already exists, skipping create"
else 
    echo "INFO | Creating Connected Cluster Resource Group $CONNECTED_CLUSTER_RESOURCE_GROUP"
    az group create --resource-group "$CONNECTED_CLUSTER_RESOURCE_GROUP" \
                    --location "$CONNECTED_CLUSTER_LOCATION" \
                    ${VERBOSE:+--debug --verbose}
    CONNECTED_CLUSTER_RESOURCE_GROUP_EXISTS='true'
    export CONNECTED_CLUSTER_RESOURCE_GROUP_EXISTS
fi

if [ "$ARC_DATA_RESOURCE_GROUP_EXISTS" = 'true' ]; then 
    echo "INFO | Arc Data Services Resource Group $ARC_DATA_RESOURCE_GROUP already exists, skipping create"
else 
    echo "INFO | Creating Arc Data Services Resource Group $ARC_DATA_RESOURCE_GROUP"
    az group create --resource-group "$ARC_DATA_RESOURCE_GROUP" \
                    --location "$ARC_DATA_LOCATION" \
                    ${VERBOSE:+--debug --verbose}
    ARC_DATA_RESOURCE_GROUP_EXISTS='true'
    export ARC_DATA_RESOURCE_GROUP_EXISTS
fi

# ====================
# 2. Connected Cluster
# ====================
if [ "$CONNECTED_CLUSTER_EXISTS" = 'true' ]; then
    echo "INFO | Connected Cluster $CONNECTED_CLUSTER already exists, skipping create"
    # 2a. Idempotent: Enable Cluster-Connect and Custom-Locations
    echo "INFO | Enabling Cluster-Connect and Custom-Locations"
    az connectedk8s enable-features -n "${CONNECTED_CLUSTER}" \
                                    -g "${CONNECTED_CLUSTER_RESOURCE_GROUP}" \
                                    --kube-config "$HOME/.kube/config" \
                                    --features cluster-connect custom-locations \
                                    "${custom_location_oid_param[@]}" \
                                    ${VERBOSE:+--debug --verbose}
else 
    echo "INFO | Creating Connected Cluster $CONNECTED_CLUSTER"
    az connectedk8s connect --name "${CONNECTED_CLUSTER}" \
                            --resource-group "${CONNECTED_CLUSTER_RESOURCE_GROUP}" \
                            --location "${CONNECTED_CLUSTER_LOCATION}" \
                            "${custom_location_oid_param[@]}" \
                            "${timeout_param[@]}" \
                            ${VERBOSE:+--debug --verbose}
    CONNECTED_CLUSTER_EXISTS='true'
    export CONNECTED_CLUSTER_EXISTS
fi

# =========================
# 3. Bootstrapper Extension
# =========================
if [ "$ARC_DATA_EXT_EXISTS" = 'true' ]; then
    echo "INFO | Bootstrapper extension $ARC_DATA_EXT already exists, skipping create"
    # 3a. Idempotent: Bootstrapper MSI Extension Permissions
    echo "INFO | Proceeding to SAMI Role Assignments on Data Services Resource Group $ARC_DATA_RESOURCE_GROUP"
  
    ARC_DATA_EXT_MSI=$(az k8s-extension show --cluster-name "${CONNECTED_CLUSTER}" --resource-group "${CONNECTED_CLUSTER_RESOURCE_GROUP}" --cluster-type connectedClusters --name "${ARC_DATA_EXT}" --query "identity.principalId" --output tsv)
    export ARC_DATA_EXT_MSI
    
    az role assignment create --assignee "${ARC_DATA_EXT_MSI}" --role 'Contributor' --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${ARC_DATA_RESOURCE_GROUP}"
    az role assignment create --assignee "${ARC_DATA_EXT_MSI}" --role 'Monitoring Metrics Publisher' --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${ARC_DATA_RESOURCE_GROUP}"
else 
    echo "INFO | Creating Bootstrapper extension $ARC_DATA_EXT"
    az k8s-extension create --name "${ARC_DATA_EXT}" \
                            --extension-type microsoft.arcdataservices \
                            --cluster-type connectedClusters \
                            --cluster-name "${CONNECTED_CLUSTER}" \
                            --resource-group "${CONNECTED_CLUSTER_RESOURCE_GROUP}" \
                            --auto-upgrade "${ARC_DATA_EXT_AUTO_UPGRADE}" \
                            --scope cluster \
                            --release-namespace "${ARC_DATA_NAMESPACE}" \
                            --config Microsoft.CustomLocation.ServiceAccount=sa-arc-bootstrapper \
                            --config systemDefaultValues.imagePullPolicy="Always" \
                            "${bootstrapper_version_param[@]}" \
                            ${VERBOSE:+--debug --verbose}
    
    # Check extension status
    ARC_DATA_EXT_STATUS=$(az k8s-extension show --cluster-name "$CONNECTED_CLUSTER" --resource-group "$CONNECTED_CLUSTER_RESOURCE_GROUP" --cluster-type connectedClusters --name "${ARC_DATA_EXT}" | jq -r '.provisioningState')

    if [ "$ARC_DATA_EXT_STATUS" = 'Succeeded' ]; then
      ARC_DATA_EXT_EXISTS='true'
      export ARC_DATA_EXT_EXISTS
    else
      echo "ERROR | Bootstrapper extension $ARC_DATA_EXT provisioning status is $ARC_DATA_EXT_STATUS, manual intervention is required"
      exit 1
    fi
fi

# ==================
# 4. Custom Location
# ==================
if [ "$ARC_DATA_CUSTOM_LOCATION_EXISTS" = 'true' ]; then
    echo "INFO | Custom Location $ARC_DATA_NAMESPACE already exists, skipping create"
else 
    echo "INFO | Creating Custom Location $ARC_DATA_NAMESPACE"
    
    CONNECTED_CLUSTER_ID=$(az connectedk8s show --name "${CONNECTED_CLUSTER}" --resource-group "${CONNECTED_CLUSTER_RESOURCE_GROUP}" --query id --output tsv)
    export CONNECTED_CLUSTER_ID

    ARC_DATA_EXT_ID=$(az k8s-extension show --cluster-name "${CONNECTED_CLUSTER}" --resource-group "${CONNECTED_CLUSTER_RESOURCE_GROUP}" --cluster-type connectedClusters --name "${ARC_DATA_EXT}" --query "id" --output tsv)
    export ARC_DATA_EXT_ID

    az customlocation create --name "${ARC_DATA_NAMESPACE}" \
                             --resource-group "${ARC_DATA_RESOURCE_GROUP}" \
                             --namespace "${ARC_DATA_NAMESPACE}" \
                             --host-resource-id "${CONNECTED_CLUSTER_ID}" \
                             --cluster-extension-ids "${ARC_DATA_EXT_ID}" \
                             --location "${CONNECTED_CLUSTER_LOCATION}" \
                             ${VERBOSE:+--debug --verbose}
    
    # Check Custom Location status
    ARC_DATA_CUSTOM_LOCATION_STATUS=$(az customlocation show --name "$ARC_DATA_NAMESPACE" --resource-group "$ARC_DATA_RESOURCE_GROUP" | jq -r '.provisioningState')

    if [ "$ARC_DATA_CUSTOM_LOCATION_STATUS" = 'Succeeded' ]; then
      ARC_DATA_CUSTOM_LOCATION_EXISTS='true'
      export ARC_DATA_CUSTOM_LOCATION_EXISTS
    else
      echo "ERROR | Custom Location $ARC_DATA_NAMESPACE provisioning status is $ARC_DATA_CUSTOM_LOCATION_STATUS, manual intervention is required"
      exit 1
    fi
fi

# ==================
# 5. Data Controller
# ==================
if [ "$ARC_DATA_CONTROLLER_EXISTS" = 'true' ]; then
    echo "INFO | Data Controller $ARC_DATA_CONTROLLER already exists, skipping create"
else 
    echo "INFO | Creating Data Controller $ARC_DATA_CONTROLLER"

    az arcdata dc create --path './custom' \
                         --name "${ARC_DATA_CONTROLLER}" \
                         --custom-location "${ARC_DATA_NAMESPACE}" \
                         --subscription "${SUBSCRIPTION_ID}" \
                         --resource-group "${ARC_DATA_RESOURCE_GROUP}" \
                         --location "${ARC_DATA_CONTROLLER_LOCATION}" \
                         --connectivity-mode direct \
                         ${VERBOSE:+--debug --verbose}

    # Check Data Controller status
    ARC_DATA_CONTROLLER_STATUS=$(az arcdata dc status show --name "$ARC_DATA_CONTROLLER" --resource-group "$ARC_DATA_RESOURCE_GROUP" | jq -r '.properties.k8SRaw.status.state')

    if [ "$ARC_DATA_CONTROLLER_STATUS" = 'Failed' ]; then
      echo "ERROR | Data Controller $ARC_DATA_CONTROLLER provisioning status is $ARC_DATA_CONTROLLER_STATUS, manual intervention is required"
      exit 1
    else
      # Loop for 10 minutes, sleeping for 30 seconds each time to see if Data Controller goes to Ready
      for i in {1..20}
      do
        echo "INFO | Waiting for Data Controller $ARC_DATA_CONTROLLER to go to ready state (attempt $i of 20)..."
        ARC_DATA_CONTROLLER_STATUS=$(az arcdata dc status show --name "$ARC_DATA_CONTROLLER" --resource-group "$ARC_DATA_RESOURCE_GROUP" | jq -r '.properties.k8SRaw.status.state')
        echo "INFO | Data Controller provisioning status: $ARC_DATA_CONTROLLER_STATUS"

        if [ "$ARC_DATA_CONTROLLER_STATUS" = 'Ready' ]; then
          ARC_DATA_CONTROLLER_EXISTS='true'
          export ARC_DATA_CONTROLLER_EXISTS
          break
        fi

        echo "INFO | Sleeping for 30 seconds..."
        sleep 30
      done
    fi
fi

# 5a. Idempotent: Apply OpenShift routes to Data Controller Monitoring UI
if [ "${OPENSHIFT}" = 'true' ]; then
  echo "INFO | Applying OpenShift routes to Data Controller $ARC_DATA_CONTROLLER"
  kubectl apply -n "${ARC_DATA_NAMESPACE}" -f './openshift/arc-data-routes.yaml'
fi

echo ""
echo "----------------------------------------------------------------------------------"
echo "INFO | Arc Data Services installer script complete"
exit 0