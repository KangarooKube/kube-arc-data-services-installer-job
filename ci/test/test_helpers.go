package test

import (
	"os"
	"testing"

	// Azure
	"github.com/Azure/azure-sdk-for-go/sdk/azcore"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
)

// To avoid wasting lots of time constantly creating and deleting Blob Storages for the tests that need to store state remotely, we created the Blob Storage ahead of time and pull as environment variables.
// We declare these as constants to avoid any ambiguity in the code - they'll be fed in via env variables in Devcontainer or CI pipeline.
const (
	TerraformStateBlobStoreNameForTestEnvVarName      = "TFSTATE_STORAGE_ACCOUNT_NAME"
	TerraformStateBlobStoreContainerForTestEnvVarName = "TFSTATE_STORAGE_ACCOUNT_CONTAINER_NAME"
	TerraformStateBlobStoreKeyForTestEnvVarName       = "TFSTATE_STORAGE_ACCOUNT_KEY"
)

// Injects environment variables into structured map for Terraform authentication with Azure
func setTerraformVariables(t *testing.T) map[string]string {

	// Grab from devcontainer environment variables
	ARM_CLIENT_ID := os.Getenv("spnClientId")
	ARM_CLIENT_SECRET := os.Getenv("spnClientSecret")
	ARM_TENANT_ID := os.Getenv("spnTenantId")
	ARM_SUBSCRIPTION_ID := os.Getenv("subscriptionId")

	// If any of the above variables are empty, return an error
	if ARM_CLIENT_ID == "" || ARM_CLIENT_SECRET == "" || ARM_TENANT_ID == "" || ARM_SUBSCRIPTION_ID == "" {
		t.Fatalf("Missing one or more of the following environment variables: spnClientId, spnClientSecret, spnTenantId, subscriptionId")
	}

	// Creating map for terraform call through Terratest
	EnvVars := make(map[string]string)

	if ARM_CLIENT_ID != "" {
		EnvVars["ARM_CLIENT_ID"] = ARM_CLIENT_ID
		EnvVars["ARM_CLIENT_SECRET"] = ARM_CLIENT_SECRET
		EnvVars["ARM_TENANT_ID"] = ARM_TENANT_ID
		EnvVars["ARM_SUBSCRIPTION_ID"] = ARM_SUBSCRIPTION_ID
	}

	return EnvVars
}

// Injects environment variables in expected naming for Azure SDK authentication with Azure
// https://docs.microsoft.com/en-us/azure/developer/go/azure-sdk-authentication?tabs=bash
func setARMVariables(t *testing.T) {

	// If any of the required variables are empty, return an error
	if os.Getenv("spnClientId") == "" || os.Getenv("spnClientSecret") == "" || os.Getenv("spnTenantId") == "" || os.Getenv("subscriptionId") == "" {
		t.Fatalf("Missing one or more of the following environment variables: spnClientId, spnClientSecret, spnTenantId, subscriptionId")
	}

	// Set environment variables for Azure SDK authentication - both permutations
	os.Setenv("AZURE_CLIENT_ID", os.Getenv("spnClientId"))
	os.Setenv("ARM_CLIENT_ID", os.Getenv("spnClientId"))
	os.Setenv("AZURE_CLIENT_SECRET", os.Getenv("spnClientSecret"))
	os.Setenv("ARM_CLIENT_SECRET", os.Getenv("spnClientSecret"))
	os.Setenv("AZURE_TENANT_ID", os.Getenv("spnTenantId"))
	os.Setenv("ARM_TENANT_ID", os.Getenv("spnTenantId"))
	os.Setenv("AZURE_SUBSCRIPTION_ID", os.Getenv("subscriptionId"))
	os.Setenv("ARM_SUBSCRIPTION_ID", os.Getenv("subscriptionId"))

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
