#!/bin/bash
set -e -o pipefail

docker build --pull --rm --platform=linux/amd64 . -t create-new-release:build
docker run -it --rm --platform=linux/amd64 docker.io/library/create-new-release:build >release.env.tmp

sed -i -e "s/\r//g" release.env.tmp

source release.env.tmp

echo "For Azure ARC Data Services versions review https://docs.microsoft.com/en-us/azure/azure-arc/data/version-log"

if [[ -z "${ARC_DATA_EXT_VER}" ]]; then
    read -p 'Input ARC_DATA_EXT_VER: ' ARC_DATA_EXT_VER
fi

if [[ -z "${ARC_DATA_CONTROLLER_VER}" ]]; then
    read -p 'Input ARC_DATA_CONTROLLER_VER: ' ARC_DATA_CONTROLLER_VER
fi

while true; do
    read -p "Does azdata extension version ${EXT_ARCDATA_VER} match Azure ARC Data Services release? " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) read -p 'Input EXT_ARCDATA_VER: ' EXT_ARCDATA_VER; exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

# output release details
echo "# Release Version Details" > ../release.env
echo "HELM_VER=${HELM_VER}" >> ../release.env
echo "KUBECTL_VER=${KUBECTL_VER}" >> ../release.env
echo "AZCLI_VER=${AZCLI_VER}" >> ../release.env
echo "EXT_K8S_CONFIGURATION_VER=${EXT_K8S_CONFIGURATION_VER}" >> ../release.env
echo "EXT_ARCDATA_VER=${EXT_ARCDATA_VER}" >> ../release.env
echo "EXT_K8S_EXTENSION_VER=${EXT_K8S_EXTENSION_VER}" >> ../release.env
echo "EXT_K8S_CONNECTEDK8S_VER=${EXT_K8S_CONNECTEDK8S_VER}" >> ../release.env
echo "EXT_K8S_CUSTOMLOCATION_VER=${EXT_K8S_CUSTOMLOCATION_VER}" >> ../release.env
echo "ARC_DATA_EXT_VER=${ARC_DATA_EXT_VER}" >> ../release.env
echo "ARC_DATA_CONTROLLER_VER=${ARC_DATA_CONTROLLER_VER}" >> ../release.env

# clean up tmp files
rm release.env.tmp
rm release.env.tmp-e