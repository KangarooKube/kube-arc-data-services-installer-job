FROM --platform=amd64 ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

USER root

RUN apt-get update && apt-get upgrade -y && \
    apt-get install ca-certificates curl apt-transport-https lsb-release gnupg apt-show-versions -y && \
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | tee /etc/apt/trusted.gpg.d/google.gpg && \
    echo "deb [arch=amd64] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list && \
    curl -s https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/helm.gpg && \
    echo "deb [arch=amd64] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list && \
    curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg && \
    AZ_REPO=$(lsb_release -cs) && \
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | tee /etc/apt/sources.list.d/azure-cli.list && \
    apt-get update && \
    apt-get install kubectl helm azure-cli jq nano -y 

COPY ./src/scripts/get-latest-versions.sh /root/get-latest-versions.sh

WORKDIR /root

ENV HOME=/root

RUN az extension add --name connectedk8s && \
    az extension add --name k8s-extension && \
    az extension add --name k8s-configuration && \
    az extension add --name customlocation && \
    az extension add --name arcdata

#ENTRYPOINT ["sleep", "infinity"]

ENTRYPOINT ["/bin/bash", "./get-latest-versions.sh"]