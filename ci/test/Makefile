# 6 hours max: https://docs.github.com/en/actions/learn-github-actions/usage-limits-billing-and-administration#usage-limits
timeout = 300m

unit-test: unit-test-aks
unit-test-aks:
	go test -timeout $(timeout) -tags "unit aks" -v

integration-test: integration-test-aks
integration-test-aks:
	go test -timeout $(timeout) -tags "integration aks" -v

test: unit-test integration-test