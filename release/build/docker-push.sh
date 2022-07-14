#!/bin/bash -x

if [ "$1" == "--no-cache" ]; then
    OPTIONS="--no-cache "
    shift
fi

IMAGE_NAME=$1
IMAGE_REPO=$2
DOCKER_FILE_DIR=$3
RELEASE_ENV=$4
RELEASE_TRAIN=$5
GITHUB_PAT=$6

echo "Building container: ${IMAGE_NAME} with Dockerfile: ${DOCKER_FILE_NAME}"
echo "Release env file: ${RELEASE_ENV}"

source ${RELEASE_ENV}

# Build docker image based on release.env file by passing into Build Args
export containerImage="${IMAGE_REPO}/${IMAGE_NAME}:${ARC_DATA_CONTROLLER_VERSION}_${RELEASE_TRAIN}"
echo $containerImage

# Base
DOCKER_BUILD_ARGS="--build-arg HELM_VERSION=${HELM_VERSION} \
                   --build-arg KUBECTL_VERSION=${KUBECTL_VERSION} \
                   --build-arg AZCLI_VERSION=${AZCLI_VERSION} \
                   --build-arg EXT_K8S_CONFIGURATION_VERSION=${EXT_K8S_CONFIGURATION_VERSION} \
                   --build-arg EXT_K8S_EXTENSION_VERSION=${EXT_K8S_EXTENSION_VERSION} \
                   --build-arg EXT_K8S_CONNECTEDK8S_VERSION=${EXT_K8S_CONNECTEDK8S_VERSION} \
                   --build-arg EXT_K8S_CUSTOMLOCATION_VERSION=${EXT_K8S_CUSTOMLOCATION_VERSION}"

# Arc Data artifacts
DOCKER_BUILD_ARGS+=" --build-arg ARC_DATA_RELEASE_TRAIN=${ARC_DATA_RELEASE_TRAIN} \
                     --build-arg ARC_DATA_EXT_VERSION=${ARC_DATA_EXT_VERSION} \
                     --build-arg ARC_DATA_CONTROLLER_VERSION=${ARC_DATA_CONTROLLER_VERSION} \
                     --build-arg ARC_DATA_WHL_URL=${ARC_DATA_WHL_URL}"

OPTIONS+="${DOCKER_BUILD_ARGS}"

# Build image with Build Args
docker build ${OPTIONS} -t ${containerImage} ${DOCKER_FILE_DIR}

# Login to GitHub and push image
echo $GITHUB_PAT | docker login ghcr.io -u KangarooKube --password-stdin
docker push ${containerImage}