#!/bin/bash
set -e -o pipefail

docker build --pull --rm --platform=linux/amd64 . -t create-new-release:build
docker run -it --rm --platform=linux/amd64 docker.io/library/create-new-release:build > release.env.tmp

sed -i -e "s/\r//g" release.env.tmp

sed -i -e "s/\r//g" release.env.tmp

source release.env.tmp

echo "For Azure ARC Data Services versions review https://docs.microsoft.com/en-us/azure/azure-arc/data/version-log"

if [[ -z "${RELEASE_VERSION}" ]]; then
    read -p 'Input RELEASE_VERSION: ' RELEASE_VERSION
fi

if [[ -z "${ARC_DATA_EXT_VERSION}" ]]; then
    read -p 'Input ARC_DATA_EXT_VERSION: ' ARC_DATA_EXT_VERSION
fi

if [[ -z "${ARC_DATA_CONTROLLER_VERSION}" ]]; then
    read -p 'Input ARC_DATA_CONTROLLER_VERSION: ' ARC_DATA_CONTROLLER_VERSION
fi

if [[ -z "${IS_WORKFLOW}" ]]; then
    while true; do
        read -p "Does az cli arcdata extension version ${EXT_ARCDATA_VERSION} match Azure ARC Data Services release? " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) read -p 'Input EXT_ARCDATA_VERSION: ' EXT_ARCDATA_VERSION; exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
else
    if [[ "${DESIRED_EXT_ARCDATA_VERSION}" ]]; then
        if [[ "${DESIRED_EXT_ARCDATA_VERSION}" != "${EXT_ARCDATA_VERSION}" ]]; then
            echo "Replacing az cli arcdata extension version ${EXT_ARCDATA_VERSION} with ${DESIRED_EXT_ARCDATA_VERSION}"
            export EXT_ARCDATA_VERSION=${DESIRED_EXT_ARCDATA_VERSION}
        fi
    fi
fi

# output release details
echo -e "\nProducing release.env file:"
echo "# Release Version Details" > ../release.env
echo "RELEASE_VERSION=${RELEASE_VERSION}" >> ../release.env
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