# Release Strategy

[July 9, 2022] Decision records:
1. Single `main` branch, containing multiple `release.env` files (4 files for 4 release trains)
2. One set of example Kustomize files maintained
3. Branch updates follow a timestamped strategy, only update one `release.env` at a time

## Steps to creating an image release:

Run this command for every `ARC_DATA_RELEASE_TRAIN` to generate a `release.${ARC_DATA_RELEASE_TRAIN}.env` file:

```bash
cd /workspaces/kube-arc-data-services-installer-job
make create-new-release-env
```

E.g. for `preview`, `stable`, run twice to generate:
- `release/release.preview.env`
- `release/release.stable.env`

Then, build + push the container images per release file in parallel via `-j`:

```bash
make -j push-new-release-image
```