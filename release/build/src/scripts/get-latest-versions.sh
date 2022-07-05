#!/bin/bash
set -e -o pipefail

# get versions
export AZ_EXT_LIST=$(az extension list)
export EXT_K8S_CONFIGURATION_VER=$(echo ${AZ_EXT_LIST} | jq -r '.[] | select(.name=="k8s-configuration") |.version')
export EXT_ARCDATA_VER=$(echo ${AZ_EXT_LIST} | jq -r '.[] | select(.name=="arcdata") |.version')
export EXT_K8S_EXTENSION_VER=$(echo ${AZ_EXT_LIST} | jq -r '.[] | select(.name=="k8s-extension") |.version')
export EXT_K8S_CONNECTEDK8S_VER=$(echo ${AZ_EXT_LIST} | jq -r '.[] | select(.name=="connectedk8s") |.version')
export EXT_K8S_CUSTOMLOCATION_VER=$(echo ${AZ_EXT_LIST} | jq -r '.[] | select(.name=="customlocation") |.version')
export HELM_PACKAGE=$(apt-show-versions helm)
export KUBECTL_PACKAGE=$(apt-show-versions kubectl)
export AZCLI_PACKAGE=$(apt-show-versions azure-cli)

# build an array from apt-show-versions to delimit values
read -ra HELM_ARRAY <<<"$HELM_PACKAGE"
read -ra KUBECTL_ARRAY <<<"$KUBECTL_PACKAGE"
read -ra AZCLI_ARRAY <<<"$AZCLI_PACKAGE"

# output release details
echo "# Release Package Versions"
echo "HELM_VER=${HELM_ARRAY[1]}"
echo "KUBECTL_VER=${KUBECTL_ARRAY[1]}"
echo "AZCLI_VER=${AZCLI_ARRAY[1]}"
echo "EXT_K8S_CONFIGURATION_VER=${EXT_K8S_CONFIGURATION_VER}"
echo "EXT_ARCDATA_VER=${EXT_ARCDATA_VER}"
echo "EXT_K8S_EXTENSION_VER=${EXT_K8S_EXTENSION_VER}"
echo "EXT_K8S_CONNECTEDK8S_VER=${EXT_K8S_CONNECTEDK8S_VER}"
echo "EXT_K8S_CUSTOMLOCATION_VER=${EXT_K8S_CUSTOMLOCATION_VER}"



