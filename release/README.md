# Building a Release image with dependencies

### Building release dependencies
We use a release image to get the latest component versions:

```bash
cd /workspaces/kube-arc-data-services-installer-job/release/build

./create-new-release.sh
```

> If any of the scripts fail, run `dos2unix create-new-release.sh` and try again.

This builds out a `release.env` file containing all of the required dependencies - e.g.

```text
# Release Version Details
HELM_VERSION=3.9.0-1
KUBECTL_VERSION=1.24.2-00
AZCLI_VERSION=2.38.0-1~jammy
EXT_K8S_CONFIGURATION_VERSION=1.5.1
EXT_K8S_EXTENSION_VERSION=1.2.3
EXT_K8S_CONNECTEDK8S_VERSION=1.2.9
EXT_K8S_CUSTOMLOCATION_VERSION=0.1.3
EXT_ARCDATA_VERSION=1.4.2
ARC_DATA_EXT_VERSION=1.2.19831003
ARC_DATA_CONTROLLER_VERSION=v1.8.0_2022-06-14
```

### Building release image

See example `/workspaces/kube-arc-data-services-installer-job/ci/terraform/aks-rbac/README.md`