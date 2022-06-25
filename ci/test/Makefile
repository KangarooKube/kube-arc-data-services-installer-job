# 6 hours max: https://docs.github.com/en/actions/learn-github-actions/usage-limits-billing-and-administration#usage-limits
timeout = 300m
GOPATH = ${HOME}/go/
PATH := ${PATH}:${GOPATH}/bin

report-prep:
	go install github.com/jstemmer/go-junit-report@latest

unit-test: report-prep unit-test-aks

unit-test-aks:
	go test -timeout $(timeout) -tags "unit aks" -v | go-junit-report -set-exit-code > report.xml 

integration-test: report-prep integration-test-aks

integration-test-aks:
	go test -timeout $(timeout) -tags "integration aks" -v | go-junit-report -set-exit-code > report.xml 

test: unit-test integration-test