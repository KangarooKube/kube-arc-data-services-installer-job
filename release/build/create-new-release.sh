#!/bin/bash
set -e -o pipefail

docker build --pull --rm --platform=linux/amd64 . -t create-new-release:build
docker run -it --rm --platform=linux/amd64 docker.io/library/create-new-release:build > release.env.tmp

sed -i -e "s/\r//g" release.env.tmp

sed -i -e "s/\r//g" release.env.tmp

source release.env.tmp

echo "For Azure ARC Data Services versions review https://docs.microsoft.com/en-us/azure/azure-arc/data/version-log"

if [[ -z "${ARC_DATA_EXT_VERSION}" ]]; then
    read -p 'Input ARC_DATA_EXT_VERSION (e.g. "1.2.19831003"): ' ARC_DATA_EXT_VERSION
fi

if [[ -z "${ARC_DATA_CONTROLLER_VERSION}" ]]; then
    read -p 'Input ARC_DATA_CONTROLLER_VERSION (e.g. "v1.8.0_2022-06-14"): ' ARC_DATA_CONTROLLER_VERSION
fi

while true; do
    read -p "Does arcdata Azure CLI Extension version ${EXT_ARCDATA_VERSION} match Azure ARC Data Services release notes? " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) read -p 'Input EXT_ARCDATA_VERSION override: ' EXT_ARCDATA_VERSION; break;;
        * ) echo "Please answer yes or no.";;
    esac
done

# output release details
echo -e "\nProducing release.env file:"
echo "# Release Version Details" > ../release.env
echo "HELM_VERSION=${HELM_VERSION}" >> ../release.env
echo "KUBECTL_VERSION=${KUBECTL_VERSION}" >> ../release.env
echo "AZCLI_VERSION=${AZCLI_VERSION}" >> ../release.env
echo "EXT_K8S_CONFIGURATION_VERSION=${EXT_K8S_CONFIGURATION_VERSION}" >> ../release.env
echo "EXT_K8S_EXTENSION_VERSION=${EXT_K8S_EXTENSION_VERSION}" >> ../release.env
echo "EXT_K8S_CONNECTEDK8S_VERSION=${EXT_K8S_CONNECTEDK8S_VERSION}" >> ../release.env
echo "EXT_K8S_CUSTOMLOCATION_VERSION=${EXT_K8S_CUSTOMLOCATION_VERSION}" >> ../release.env
echo "EXT_ARCDATA_VERSION=${EXT_ARCDATA_VERSION}" >> ../release.env
echo "ARC_DATA_EXT_VERSION=${ARC_DATA_EXT_VERSION}" >> ../release.env
echo "ARC_DATA_CONTROLLER_VERSION=${ARC_DATA_CONTROLLER_VERSION}" >> ../release.env

echo -e "\n$(cat ../release.env)"

# clean up tmp files
rm release.env.tmp
rm release.env.tmp-e