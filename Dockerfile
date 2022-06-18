FROM --platform=amd64 ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

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
    apt-get install kubectl helm azure-cli jq nano -y && \
    apt-get remove apt-transport-https gnupg lsb-release -y && \
    apt-get autoclean && apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives && \
    groupadd -g 1001 -r container-user && \
    useradd --no-log-init -u 1001 -r -m -g container-user container-user && \
    chown -R 1001:1001 /home/container-user && \
    usermod -d /home/container-user container-user

# Uncomment for Cache invalidation to get the latest CLI Extensions
# ARG CACHEBUST=1

USER container-user

WORKDIR /home/container-user

ENV HOME=/home/container-user

RUN az extension add --name connectedk8s && \
    az extension add --name k8s-extension && \
    az extension add --name k8s-configuration && \
    az extension add --name customlocation && \
    az extension add --name arcdata

COPY ./src/scripts /home/container-user

ENTRYPOINT ["/bin/bash", "./install-arc-data-services.sh"]