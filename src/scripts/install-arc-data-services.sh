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

if [[ -z "${DELETE_FLAG}" ]]; then
  echo "INFO | DELETE_FLAG is not set, defaulting to false"
  export DELETE_FLAG='false'
fi

if [ "${DELETE_FLAG}" = 'false' ]; then
  echo "INFO | Starting Arc + Data Services onboarding process"
fi

if [[ -z "${DELETE_FLAG}" ]]; then
  if [[ -z "${CONNECTED_CLUSTER_LOCATION}" ]]; then
    echo "ERROR | variable CONNECTED_CLUSTER_LOCATION is required for cluster onboarding."
    exit 1
  fi
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
echo ""

# ====================
# Central Status Check
# ====================
# .
# └── 1. Connected Cluster and Data Services RG
#     └── 2. Connected Cluster
#         ├── 3. Bootstrapper Extension
#         └── 4. Idempotent feature enablement - Cluster-Connect and Custom-Locations
#             └── 5. Custom Location (needs cluster-connect and custom-location enabled)
#                 └── 6. Data Controller

# 1. Connected Cluster and Data Services RG
CONNECTED_CLUSTER_RESOURCE_GROUP_EXISTS=$(az group list | jq -r ".[] | select(.name==\"$CONNECTED_CLUSTER_RESOURCE_GROUP\") |.name")
export CONNECTED_CLUSTER_RESOURCE_GROUP_EXISTS
ARC_DATA_SERVICES_RESOURCE_GROUP_EXISTS=$(az group list | jq -r ".[] | select(.name==\"$ARC_DATA_SERVICES_RESOURCE_GROUP\") |.name")
export ARC_DATA_SERVICES_RESOURCE_GROUP_EXISTS

# 1. Check dependents:
if [[ -n "${CONNECTED_CLUSTER_RESOURCE_GROUP_EXISTS}" ]] && [[ -n "${ARC_DATA_SERVICES_RESOURCE_GROUP_EXISTS}" ]]; then
  
  # 2. Connected Cluster
  CONNECTED_CLUSTER_EXISTS=$(az resource list --name "$CONNECTED_CLUSTER" --resource-group "$CONNECTED_CLUSTER_RESOURCE_GROUP" --query "[?contains(type,'Microsoft.Kubernetes/connectedClusters')].name" --output tsv)
  export CONNECTED_CLUSTER_EXISTS

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
ARC_DATA_SERVICES_RESOURCE_GROUP_EXISTS=$(true_if_nonempty "${ARC_DATA_SERVICES_RESOURCE_GROUP_EXISTS}")
CONNECTED_CLUSTER_EXISTS=$(true_if_nonempty "${CONNECTED_CLUSTER_EXISTS}")

echo ""
echo "INFO | CONNECTED_CLUSTER_RESOURCE_GROUP_EXISTS? $CONNECTED_CLUSTER_RESOURCE_GROUP_EXISTS"
echo "INFO | ARC_DATA_SERVICES_RESOURCE_GROUP_EXISTS? $ARC_DATA_SERVICES_RESOURCE_GROUP_EXISTS"
echo "INFO | CONNECTED_CLUSTER_EXISTS? $CONNECTED_CLUSTER_EXISTS"
echo ""

# ======================
# Handle delete and exit
# ======================
if [ "${DELETE_FLAG}" = 'true' ]; then
  echo "INFO | Starting Arc + Data Services destruction process"

  # ...

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
  if [ "$ARC_DATA_SERVICES_RESOURCE_GROUP_EXISTS" = 'true' ]; then 
    echo "INFO | Deleting Arc Data Services Resource Group $ARC_DATA_SERVICES_RESOURCE_GROUP"
      az group delete --resource-group "$ARC_DATA_SERVICES_RESOURCE_GROUP" \
                      --yes \
                      ${VERBOSE:+--debug --verbose}
  else 
    echo "INFO | Arc Data Services Resource Group $ARC_DATA_SERVICES_RESOURCE_GROUP doest not exist, skipping delete"
  fi

  if [ "$CONNECTED_CLUSTER_RESOURCE_GROUP_EXISTS" = 'true' ]; then 
    echo "INFO | Deleting Connected Cluster Resource Group $CONNECTED_CLUSTER_RESOURCE_GROUP"
      az group delete --resource-group "$CONNECTED_CLUSTER_RESOURCE_GROUP" \
                      --yes \
                      ${VERBOSE:+--debug --verbose}
  else 
    echo "INFO | Connected Cluster Resource Group $CONNECTED_CLUSTER_RESOURCE_GROUP doest not exist, skipping delete"
  fi

  echo ""
  echo "----------------------------------------------------------------------------------"
  echo "INFO | Destruction complete."
  exit 0
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

if [ "$ARC_DATA_SERVICES_RESOURCE_GROUP_EXISTS" = 'true' ]; then 
    echo "INFO | Arc Data Services Resource Group $ARC_DATA_SERVICES_RESOURCE_GROUP already exists, skipping create"
else 
    echo "INFO | Creating Arc Data Services Resource Group $ARC_DATA_SERVICES_RESOURCE_GROUP"
    az group create --resource-group "$ARC_DATA_SERVICES_RESOURCE_GROUP" \
                    --location "$ARC_DATA_SERVICES_LOCATION" \
                    ${VERBOSE:+--debug --verbose}
    ARC_DATA_SERVICES_RESOURCE_GROUP_EXISTS='true'
    export ARC_DATA_SERVICES_RESOURCE_GROUP_EXISTS
fi

# ====================
# 2. Connected Cluster
# ====================

if [ "$CONNECTED_CLUSTER_EXISTS" = 'true' ]; then
    echo "INFO | Connected Cluster $CONNECTED_CLUSTER already exists, skipping create"
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

echo ""
echo "----------------------------------------------------------------------------------"
echo "INFO | Arc Data Services installer script complete"
exit 0