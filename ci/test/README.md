# Automated testing

This folder contains examples of how to write automated tests for infrastructure code using Go and
[Terratest](https://terratest.gruntwork.io/).

## Pre-requisites

* Launch this `.devcontainer`
* You must have an Azure Service Principal with `Contributor` priveleges injected into this container.

## Quick start

First time build:
```bash
cd /workspaces/kube-arc-data-services-installer-job/ci/test

# Can call it whatever we want - in this case our repo name
go mod init github.com/kangarookube/kube-arc-data-services-installer-job

# This creates a go.sum file with all our dependencies linked to git commits, and cleans up ones not required
go mod tidy
```

Run all the test modules:

```bash
go test -v -timeout 90m
```

Run specific modules and all test cases within it:

```bash
# Deploy AKS Cluster with RBAC enabled, verbose logs
go test -v -timeout 300m -run 'TestAksIntegrationWithStages'
```

## Development workflow via `Stages`

Example:

```bash
# Blow away old local state from previous clusters
MODULE_PATH='/workspaces/kube-arc-data-services-installer-job/ci/terraform/aks-rbac'
rm -rf ${MODULE_PATH}/.terraform
rm -rf ${MODULE_PATH}/.test-data
rm -rf ${MODULE_PATH}/.terraform.lock.hcl

# 1. Deploy one-time
SKIP_teardown_aks=true \
go test -v -timeout 300m -run 'TestAksIntegrationWithStages'
# ...

# 2. Iterate on validation - tweak stages to skip as we go
SKIP_teardown_aks=true \
SKIP_deploy_aks=true \
go test -v -timeout 300m -run 'TestAksIntegrationWithStages'
# ...

# 3. Destroy when done development
SKIP_deploy_aksTf=true \
go test -v -timeout 300m -run 'TestAksIntegrationWithStages'
```