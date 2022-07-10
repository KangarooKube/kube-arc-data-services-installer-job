#!/bin/bash
set -e -o pipefail

docker build --pull --rm --platform=linux/amd64 . -t create-new-release:build
docker run -it --rm --platform=linux/amd64 docker.io/library/create-new-release:build > release.env.tmp

# Clean up newlines in env variables
sed -i -e "s/\r//g" release.env.tmp

source release.env.tmp

echo "=============================="
echo "Arc extension release trains: "
echo "=============================="
echo "Available commands: https://docs.microsoft.com/en-us/cli/azure/k8s-extension"
echo ""
echo "Arc Data versions:"
echo ""
echo " stable: https://docs.microsoft.com/en-us/azure/azure-arc/data/version-log"
echo " test, preview: https://docs.microsoft.com/en-us/azure/azure-arc/data/preview-testing"
echo ""
echo "az arcdata wheel file information:"
echo ""
echo " stable: https://azcliextensionsync.blob.core.windows.net/index1/index.json"
echo " test, preview downloads: https://docs.microsoft.com/en-us/azure/azure-arc/data/preview-testing#current-preview-release-information"
echo ""
echo ""
echo "4 hierarchial, interdependent artifacts are required to uniquely localize a deployment:"
echo ""
echo "└── 1. Extension release train: ARC_DATA_RELEASE_TRAIN"
echo "    └── 2. Extension version: ARC_DATA_EXT_VERSION"
echo "        └── 3. Data Controller image tag: ARC_DATA_CONTROLLER_VERSION"
echo "            └── 4. CLI Extension downoad URL for az arcdata wheel file: ARC_DATA_WHL_URL"
echo ""

if [[ -z "${ARC_DATA_RELEASE_TRAIN}" ]]; then
    read -p '1. Input ARC_DATA_RELEASE_TRAIN            | e.g. "test, preview or stable": ' ARC_DATA_RELEASE_TRAIN
fi

if [[ -z "${ARC_DATA_EXT_VERSION}" ]]; then
    read -p '2. Input ARC_DATA_EXT_VERSION              | e.g. "1.2.19831003"): ' ARC_DATA_EXT_VERSION
fi

if [[ -z "${ARC_DATA_CONTROLLER_VERSION}" ]]; then
    read -p '3. Input ARC_DATA_CONTROLLER_VERSION       | e.g. "v1.8.0_2022-06-14"): ' ARC_DATA_CONTROLLER_VERSION
fi

if [[ -z "${ARC_DATA_WHL_URL}" ]]; then
    read -p '4. Input ARC_DATA_WHL_URL                  | e.g. "https://arcdataazurecliextension.blob.core.windows.net/stage/arcdata-1.4.3-py2.py3-none-any.whl"): ' ARC_DATA_WHL_URL
fi

# output release details
echo -e "\nProducing release.${ARC_DATA_RELEASE_TRAIN}.env file:"
echo "# Base artifacts:" > ../release.${ARC_DATA_RELEASE_TRAIN}.env
echo "HELM_VERSION=${HELM_VERSION}" >> ../release.${ARC_DATA_RELEASE_TRAIN}.env
echo "KUBECTL_VERSION=${KUBECTL_VERSION}" >> ../release.${ARC_DATA_RELEASE_TRAIN}.env
echo "AZCLI_VERSION=${AZCLI_VERSION}" >> ../release.${ARC_DATA_RELEASE_TRAIN}.env
echo "EXT_K8S_CONFIGURATION_VERSION=${EXT_K8S_CONFIGURATION_VERSION}" >> ../release.${ARC_DATA_RELEASE_TRAIN}.env
echo "EXT_K8S_EXTENSION_VERSION=${EXT_K8S_EXTENSION_VERSION}" >> ../release.${ARC_DATA_RELEASE_TRAIN}.env
echo "EXT_K8S_CONNECTEDK8S_VERSION=${EXT_K8S_CONNECTEDK8S_VERSION}" >> ../release.${ARC_DATA_RELEASE_TRAIN}.env
echo "EXT_K8S_CUSTOMLOCATION_VERSION=${EXT_K8S_CUSTOMLOCATION_VERSION}" >> ../release.${ARC_DATA_RELEASE_TRAIN}.env
echo "# Arc Data artifacts:" >> ../release.${ARC_DATA_RELEASE_TRAIN}.env
echo "ARC_DATA_RELEASE_TRAIN=${ARC_DATA_RELEASE_TRAIN}" >> ../release.${ARC_DATA_RELEASE_TRAIN}.env
echo "ARC_DATA_EXT_VERSION=${ARC_DATA_EXT_VERSION}" >> ../release.${ARC_DATA_RELEASE_TRAIN}.env
echo "ARC_DATA_CONTROLLER_VERSION=${ARC_DATA_CONTROLLER_VERSION}" >> ../release.${ARC_DATA_RELEASE_TRAIN}.env
echo "ARC_DATA_WHL_URL=${ARC_DATA_WHL_URL}" >> ../release.${ARC_DATA_RELEASE_TRAIN}.env

echo -e "\n$(cat ../release.${ARC_DATA_RELEASE_TRAIN}.env)"

# clean up tmp files
rm -f release.env.tmp
rm -f release.env.tmp-e