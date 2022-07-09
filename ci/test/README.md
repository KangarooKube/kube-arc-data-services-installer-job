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

Run unit tests - basically `terraform plan`:

```bash
make unit-test
```

Run integration tests - which is End-to-end:

```bash
make integration-test
```

Run both:

```bash
make test
```

## Development workflow via `Stages`

Example:

```bash
# Blow away old local state from previous clusters
MODULE_PATH='/workspaces/kube-arc-data-services-installer-job/ci/terraform/aks-rbac'
rm -rf ${MODULE_PATH}/.terraform
rm -rf ${MODULE_PATH}/.test-data
rm -rf ${MODULE_PATH}/.terraform.lock.hcl
rm -rf ${MODULE_PATH}/terraform.tfstate
rm -rf ${MODULE_PATH}/terraform.tfstate.backup

# 1. Deploy fully one-time, skip destruction
SKIP_teardown_aks=true \
go test -timeout 300m -run 'TestAksIntegrationWithStages' -tags "integration aks" -v -args -releaseTrain=preview 2>&1 | tee test.log
# ...

# 2. Iterate on validation - tweak stages to skip as we go
SKIP_teardown_aks=true \
SKIP_deploy_aks=true \
go test -timeout 300m -run 'TestAksIntegrationWithStages' -tags "integration aks" -v -args -releaseTrain=preview 2>&1 | tee test.log
# ...

# 3. Destroy when done development
SKIP_deploy_aks=true \
go test -timeout 300m -run 'TestAksIntegrationWithStages' -tags "integration aks" -v -args -releaseTrain=preview 2>&1 | tee test.log

# All options available

# SKIP_teardown_aks=true \
# SKIP_deploy_aks=true \
# SKIP_validate_aks=true \
# SKIP_build_and_push_image=true \
# SKIP_onboard_arc=true \
# SKIP_validate_arc_onboarding=true \
# SKIP_destroy_arc=true \
# SKIP_validate_arc_offboarding=true \
```

Tips:
* After the first time deploy, always include `SKIP_deploy_aks=true`, because otherwise Terraform will try to deploy a whole new state file and whole new resources with a uniqueID, and that will mess up your Terratest local folder. If you do this, workaround is to go inside the Terratest local folder and replace the UniqueID as it used to be (get this from Blob Storage).
* If debugging doesn't work with `F5`, try to `Go: Restart language server`. If that still doesn't work, rebuild the container, and install all the popup packages, then try again.
  
  > First time might take a bit of time to spin up as Terraform spins up
* Append `2>&1 | tee test.log` to pipe to screen and file