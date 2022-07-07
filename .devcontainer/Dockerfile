# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.195.0/containers/go/.devcontainer/base.Dockerfile
# [Choice] https://github.com/microsoft/vscode-dev-containers/blob/main/containers/go/.devcontainer/Dockerfile
ARG VARIANT=1.18
FROM mcr.microsoft.com/vscode/devcontainers/go:0-${VARIANT}


# Install additional OS packages.
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get -y install --no-install-recommends \
     apt-utils \
     dialog \
     git \
     iproute2 \
     procps \
     bash-completion \
     wget \
     unzip \
     dos2unix \
     tree \
     make \
     tmux \
     gettext-base \
     gcc \
     mono-mcs \
     apt-transport-https \
     gnupg2 \
     lsb-release \
     ca-certificates \
     curl \
     gnupg-agent \
     software-properties-common

# Install go packages if not present
# RUN go install -v github.com/cweill/gotests/gotests@latest \
#     && go install -v github.com/fatih/gomodifytags@latest \
#     && go install -v github.com/josharian/impl@latest \
#     && go install -v github.com/haya14busa/goplay/cmd/goplay@latest \
#     && go install -v honnef.co/go/tools/cmd/staticcheck@latest \
#     && go install -v golang.org/x/tools/gopls@latest \
#     && go install -v github.com/go-delve/delve/cmd/dlv@latest

# Install Terraform
ARG TF_Version="1.2.3"
RUN wget --quiet https://releases.hashicorp.com/terraform/${TF_Version}/terraform_${TF_Version}_linux_amd64.zip \
  && unzip terraform_${TF_Version}_linux_amd64.zip \
  && mv terraform /usr/bin \
  && rm terraform_${TF_Version}_linux_amd64.zip

# Install the Azure CLI
ARG AZCLI_VERSION=2.38.0-1~bullseye
RUN apt-get install -y apt-transport-https gnupg2 lsb-release \
    && echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/azure-cli.list \
    && curl -sL https://packages.microsoft.com/keys/microsoft.asc | apt-key add - 2>/dev/null \
    && apt-get update \
    && apt-get install -y azure-cli=${AZCLI_VERSION} \
    && az config set extension.use_dynamic_install=yes_without_prompt

# Install Docker CLI and Compose
RUN apt-get update \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo \
       "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
       $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce docker-ce-cli docker-compose-plugin

# Install Kubectl
RUN echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list \
    && curl -sL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - 2>/dev/null \
    && apt-get update \
    && apt-get install -y kubectl

# Install yq
# Latest on https://launchpad.net/~rmescandon/+archive/ubuntu/yq is v4.25.1
ARG VERSION=v4.25.1
ARG BINARY=yq_linux_386
RUN wget https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY} -O /usr/bin/yq \
    && chmod +x /usr/bin/yq

# Clean up
RUN apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/downloads

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=dialog