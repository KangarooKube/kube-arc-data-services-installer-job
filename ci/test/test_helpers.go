package test

import (
	"fmt"
	"os"
	"strings"
	"testing"

	// Terragrunt
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"

	// Azure
	"github.com/Azure/azure-sdk-for-go/sdk/azcore"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	// Testing
)

// To avoid wasting lots of time constantly creating and deleting Blob Storages for the tests that need to store state remotely, we created the Blob Storage ahead of time and pull as environment variables.
// We declare these as constants to avoid any ambiguity in the code - they'll be fed in via env variables in Devcontainer or CI pipeline.
const (
	aksTfModuleDir          = "terraform/aks-rbac" // Relative path from ci root to the AKS terraform module
	k8sBasePayloadDir       = "../../kustomize/base"
	k8sAksOverlayPayloadDir = "../../kustomize/overlays/aks"
	k8sPayloadTempDir       = "../../kustomize/.temp"
	containerName           = "kube-arc-data-services-installer-job"
	containerVersion        = "0.1.0" // Pass this in as an env variable with the Git commit hash instead
	dockerFilePath          = "../../"
	releaseEnvFilePath      = "../../release/release.env"
	namePrefix              = "arcCIAksTf"
	deploymentLocation      = "canadacentral"
	jobNamespace            = "azure-arc-kubernetes-bootstrap"
	jobName                 = "azure-arc-kubernetes-bootstrap"
	arcInstallTimeOutInMins = 45
)

// Creates Terraform Options for AKS with remote state backend
//
// There's two design options:
//
// 1. Include hostname in ID - which would allow ust to run the command below in an idempotent fashion
//
//	Pros:
//		- Can run Unit test over and over without cleaning remote state file
//  Cons:
//		- Can only run one integration test run on a given machine at a time since State file will conflict
// 		- Resouce names will include uniqueID anyway so Terraform will try to recreate resources - meaning this idempotent approach is useless for Integration Tests to start
//
// 	Sample implementation
// 		hostname, err := os.Hostname()
//		require.NoError(t, err)
//		storageAccountStateKey := fmt.Sprintf("%s/%s/terraform.tfstate", t.Name(), hostname)
//
// 2. Include unique ID - which means the command below can only be run once per machine without state file conflict
//
//  Pros:
// 		- Can run multiple Integration tests at once on a given machine
//      - For local dev, terratest include stage skips which would circumvent this anyway
//		- Unit tests can just run over and over and generate unique state file, who cares, there's no ARM resources
//  Cons:
//		- Each run of the Unit test needs to clean up the remote state file
//
// Implemented Option 2 - as there are way more benefits - as long as we Skip the redeploy stage locally we're set
func createaksTfOpts(t *testing.T, terraformDir string) *terraform.Options {
	uniqueId := strings.ToLower(random.UniqueId())

	// Ensures env variables are injected in before creating the Options which get stored in the state file
	setARMVariables(t)

	return &terraform.Options{
		// Set the path to the Terraform code that will be tested.
		TerraformDir: terraformDir,

		// Variables to pass to our Terraform code using -var options.
		Vars: map[string]interface{}{
			"resource_prefix": fmt.Sprintf("%s%s", namePrefix, uniqueId),
			"location":        deploymentLocation,
			"tags": map[string]string{
				"Source":  "terratest",
				"Owner":   "Raki Rahman",
				"Project": "Terraform CI testing for Arc Install",
			},
		},

		// Colors in Terraform commands - we like colors
		NoColor: false,
	}
}

// Injects environment variables in expected naming for Azure and Terraform SDK authentication with Azure
// https://docs.microsoft.com/en-us/azure/developer/go/azure-sdk-authentication?tabs=bash
// https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret#configuring-the-service-principal-in-terraform
func setARMVariables(t *testing.T) {

	// If any of the required secret variables are empty in this environment, return an error
	if os.Getenv("SPN_CLIENT_ID") == "" || os.Getenv("SPN_CLIENT_SECRET") == "" || os.Getenv("SPN_TENANT_ID") == "" || os.Getenv("SPN_SUBSCRIPTION_ID") == "" {
		t.Fatalf("Missing one or more of the following environment variables: SPN_CLIENT_ID, SPN_CLIENT_SECRET, SPN_TENANT_ID, SPN_SUBSCRIPTION_ID")
	}

	// Set environment variables for Azure SDK authentication - both permutations
	os.Setenv("AZURE_CLIENT_ID", os.Getenv("SPN_CLIENT_ID"))
	os.Setenv("ARM_CLIENT_ID", os.Getenv("SPN_CLIENT_ID"))
	os.Setenv("AZURE_CLIENT_SECRET", os.Getenv("SPN_CLIENT_SECRET"))
	os.Setenv("ARM_CLIENT_SECRET", os.Getenv("SPN_CLIENT_SECRET"))
	os.Setenv("AZURE_TENANT_ID", os.Getenv("SPN_TENANT_ID"))
	os.Setenv("ARM_TENANT_ID", os.Getenv("SPN_TENANT_ID"))
	os.Setenv("AZURE_SUBSCRIPTION_ID", os.Getenv("SPN_SUBSCRIPTION_ID"))
	os.Setenv("ARM_SUBSCRIPTION_ID", os.Getenv("SPN_SUBSCRIPTION_ID"))

}

// Authenticates to Azure and initiates context
func getAzureCred(t *testing.T) azcore.TokenCredential {

	// Grabs Azure SDK authentication environment variables
	setARMVariables(t)

	// Authenticates using Environment variables grabbed
	cred, err := azidentity.NewDefaultAzureCredential(nil)
	if err != nil {
		t.Fatalf("Azure Authentication failed with: %s", err.Error())
	}

	return cred
}

// Gets the value of the environment variable with the given name. If that environment variable is not set, fail the test.
func GetRequiredEnvVar(t *testing.T, envVarName string) string {

	envVarValue := os.Getenv(envVarName)

	if envVarValue == "" {
		t.Fatalf("Required environment variable '%s' is not set", envVarName)
	}

	return envVarValue
}

// Split string based on delimiter
func splitStringIntoArrayBasedOnDelimiter(t *testing.T, str string, delimiter string) []string {

	// Split the string based on the delimiter
	splitStr := strings.Split(str, delimiter)

	// If the split string is empty, return an error
	if len(splitStr) == 0 {
		t.Fatalf("String '%s' was not split into array based on delimiter '%s'", str, delimiter)
	}

	return splitStr
}

// Removes duplicates from the array
func removeDuplicatesFromArray(t *testing.T, arr []string) []string {

	// Create a map to store the unique values
	uniqueValues := make(map[string]bool)

	// Iterate over the array and add the values to the map
	for _, value := range arr {
		uniqueValues[value] = true
	}

	// Create a new array to store the unique values
	uniqueArray := make([]string, 0)

	// Iterate over the map and add the values to the new array
	for key := range uniqueValues {
		uniqueArray = append(uniqueArray, key)
	}

	return uniqueArray
}
