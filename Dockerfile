FROM --platform=amd64 ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

# Set build time variables
ARG HELM_VERSION
ARG KUBECTL_VERSION
ARG AZCLI_VERSION
ARG EXT_K8S_CONFIGURATION_VERSION
ARG EXT_ARCDATA_VERSION
ARG EXT_K8S_EXTENSION_VERSION
ARG EXT_K8S_CONNECTEDK8S_VERSION
ARG EXT_K8S_CUSTOMLOCATION_VERSION
# Set runtime defaults
ARG ARC_DATA_EXT_VERSION
ARG ARC_DATA_CONTROLLER_VERSION
ENV ARC_DATA_EXT_VERSION=$ARC_DATA_EXT_VERSION
ENV ARC_DATA_CONTROLLER_VERSION=$ARC_DATA_CONTROLLER_VERSION

# Validate
RUN echo "HELM_VERSION: ${HELM_VERSION}\n" \
 && echo "KUBECTL_VERSION: ${KUBECTL_VERSION}\n" \
 && echo "AZCLI_VERSION: ${AZCLI_VERSION}\n" \
 && echo "EXT_K8S_CONFIGURATION_VERSION: ${EXT_K8S_CONFIGURATION_VERSION}\n" \
 && echo "EXT_ARCDATA_VERSION: ${EXT_ARCDATA_VERSION}\n" \
 && echo "EXT_K8S_EXTENSION_VERSION: ${EXT_K8S_EXTENSION_VERSION}\n" \
 && echo "EXT_K8S_CONNECTEDK8S_VERSION: ${EXT_K8S_CONNECTEDK8S_VERSION}\n" \
 && echo "EXT_K8S_CUSTOMLOCATION_VERSION: ${EXT_K8S_CUSTOMLOCATION_VERSION}\n" \
 && echo "ARC_DATA_EXT_VERSION: ${ARC_DATA_EXT_VERSION}\n" \
 && echo "ARC_DATA_CONTROLLER_VERSION: ${ARC_DATA_CONTROLLER_VERSION}\n"

USER root

RUN apt-get update && apt-get upgrade -y && \
    apt-get install ca-certificates curl apt-transport-https lsb-release gnupg -y && \
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | tee /etc/apt/trusted.gpg.d/google.gpg && \
    echo "deb [arch=amd64] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list && \
    curl -s https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/helm.gpg && \
    echo "deb [arch=amd64] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list && \
    curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg && \
    AZ_REPO=$(lsb_release -cs) && \
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | tee /etc/apt/sources.list.d/azure-cli.list && \
    apt-get update && \
    apt-get install kubectl=${KUBECTL_VERSION} helm=${HELM_VERSION} azure-cli=${AZCLI_VERSION} jq -y && \
    apt-get remove apt-transport-https gnupg lsb-release -y && \
    apt-get autoclean && apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives && \
    groupadd -g 1001 -r container-user && \
    useradd --no-log-init -u 1001 -r -m -g container-user container-user && \
    chown -R 1001:1001 /home/container-user && \
    usermod -d /home/container-user container-user

COPY ./src/scripts/install-arc-data-services.sh /home/container-user/install-arc-data-services.sh

USER container-user

WORKDIR /home/container-user

ENV HOME=/home/container-user

RUN az extension add --name connectedk8s --version ${EXT_K8S_CONNECTEDK8S_VERSION} && \
    az extension add --name k8s-extension --version ${EXT_K8S_EXTENSION_VERSION} && \
    az extension add --name k8s-configuration --version ${EXT_K8S_CONFIGURATION_VERSION} && \
    az extension add --name customlocation --version ${EXT_K8S_CUSTOMLOCATION_VERSION} && \
    az extension add --name arcdata --version ${EXT_ARCDATA_VERSION}

ENTRYPOINT ["/bin/bash", "./install-arc-data-services.sh"]