FROM --platform=amd64 ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

# Set component versions
ARG HELM_VER=3.9.0-1
ARG KUBECTL_VER=1.24.2-00
ARG AZCLI_VER=2.37.0-1~jammy
ARG EXT_K8S_CONFIGURATION_VER=1.5.1
ARG EXT_ARCDATA_VER=1.4.2
ARG EXT_K8S_EXTENSION_VER=1.2.3
ARG EXT_K8S_CONNECTEDK8S_VER=1.2.9
ARG EXT_K8S_CUSTOMLOCATION_VER=0.1.3

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
    apt-get install kubectl=${KUBECTL_VER} helm=${HELM_VER} azure-cli=${AZCLI_VER} jq -y && \
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

RUN az extension add --name connectedk8s --version ${EXT_K8S_CONNECTEDK8S_VER} && \
    az extension add --name k8s-extension --version ${EXT_K8S_EXTENSION_VER} && \
    az extension add --name k8s-configuration --version ${EXT_K8S_CONFIGURATION_VER} && \
    az extension add --name customlocation --version ${EXT_K8S_CUSTOMLOCATION_VER} && \
    az extension add --name arcdata --version ${EXT_ARCDATA_VER}

ENTRYPOINT ["/bin/bash", "./install-arc-data-services.sh"]