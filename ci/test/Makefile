# 6 hours max: https://docs.github.com/en/actions/learn-github-actions/usage-limits-billing-and-administration#usage-limits
timeout              = 300m
GOPATH               = ${HOME}/go/
PATH                 := ${PATH}:${GOPATH}/bin
SHELL                := /bin/bash
TF_ROOT              = $(shell git rev-parse --show-toplevel)/ci/terraform/aks-rbac

report-prep:
	go install github.com/jstemmer/go-junit-report@latest

unit-test: report-prep unit-test-aks

unit-test-aks:
	go test -timeout $(timeout) -tags "unit aks" -v | tee unit-test-log.out
	cat unit-test-log.out | go-junit-report > unit-test-report.xml

integration-test: report-prep integration-test-aks

integration-test-aks: integration-test-aks-preview integration-test-aks-stable

# TODO: --release-train = test

integration-test-aks-preview: report-prep
	go test -timeout $(timeout) -tags "integration aks" -v -args -releaseTrain=preview | tee integration-test-log-preview.out
	cat integration-test-log-preview.out | go-junit-report > integration-test-report-preview.xml

integration-test-aks-stable: report-prep
	go test -timeout $(timeout) -tags "integration aks" -v -args -releaseTrain=stable | tee integration-test-log-stable.out
	cat integration-test-log-stable.out | go-junit-report > integration-test-report-stable.xml

test: unit-test integration-test

clean-local-terraform-state:
	@rm -rf $(TF_ROOT)/.terraform
	@rm -rf $(TF_ROOT)/.test-data
	@rm -rf $(TF_ROOT)/.terraform.lock.hcl
	@rm -rf $(TF_ROOT)/terraform.tfstate
	@rm -rf $(TF_ROOT)/terraform.tfstate.backup