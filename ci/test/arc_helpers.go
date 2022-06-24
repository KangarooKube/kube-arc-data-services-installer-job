package test

import (
	"context"
	"fmt"
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"

	// Azure
	"github.com/Azure/azure-sdk-for-go/sdk/azcore"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/azurearcdata/armazurearcdata"                       // Data Controller
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/extendedlocation/armextendedlocation"               // Custom Location
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/hybridkubernetes/armhybridkubernetes"               // Connected Cluster
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/kubernetesconfiguration/armkubernetesconfiguration" // Extensions
)

// Injects environment variables for Arc ConfigMap/Secret creation for Kustomize
// This function first checks if a value is already passed in, if not, it sets reasonable defaults

// Full list:
// export TENANT_ID=$spnTenantId                                 # Set from existing env variable
// export SUBSCRIPTION_ID=$subscriptionId						 #                 "
// export CLIENT_ID=$spnClientId								 #                 "
// export CLIENT_SECRET=$spnClientSecret					     #                 "
// export AZDATA_USERNAME='boor'						 		 # boor
// export AZDATA_PASSWORD='acntorPRESTO!'                        # acntorPRESTO!
// export CONNECTED_CLUSTER_RESOURCE_GROUP="$resourceGroup-arc"  # Append "arc" to existing RG's name
// export CONNECTED_CLUSTER_LOCATION="eastasia"                  # If set use, if not, set to eastasia
// export ARC_DATA_RESOURCE_GROUP="$resourceGroup-arc-data"	     # Append "arc-data" to  existing RG's name
// export ARC_DATA_LOCATION="eastasia"                           # If set use, if not, set to eastasia
// export CONNECTED_CLUSTER=$clusterName					     # Use name of AKS Cluster created by Terraform
// export ARC_DATA_EXT="arc-data-bootstrapper"					 # arc-data-bootstrapper
// export ARC_DATA_EXT_AUTO_UPGRADE="false"						 # false
// export ARC_DATA_EXT_VERSION="1.2.19831003"                    # if set use, if not, throw error
// export ARC_DATA_NAMESPACE="azure-arc-data"					 # azure-arc-data
// export ARC_DATA_CONTROLLER="azure-arc-data-controller"		 # azure-arc-data-controller
// export ARC_DATA_CONTROLLER_LOCATION="southeastasia"           # If set use, if not, set to southeastasia
// export DELETE_FLAG='false'									 # Starts false - will be overwritten to true during test

func setArcJobVariables(t *testing.T, aksTfOpts *terraform.Options) {
	os.Setenv("TENANT_ID", os.Getenv("spnTenantId"))
	os.Setenv("SUBSCRIPTION_ID", os.Getenv("subscriptionId"))
	os.Setenv("CLIENT_ID", os.Getenv("spnClientId"))
	os.Setenv("CLIENT_SECRET", os.Getenv("spnClientSecret"))
	os.Setenv("AZDATA_USERNAME", "boor")
	os.Setenv("AZDATA_PASSWORD", "acntorPRESTO!")

	// Unique prefix for this deployment
	inputResourcePrefix := aksTfOpts.Vars["resource_prefix"].(string)

	os.Setenv("CONNECTED_CLUSTER_RESOURCE_GROUP", fmt.Sprintf("%s-arc", inputResourcePrefix))
	if os.Getenv("CONNECTED_CLUSTER_LOCATION") == "" {
		os.Setenv("CONNECTED_CLUSTER_LOCATION", "eastasia")
	}
	os.Setenv("ARC_DATA_RESOURCE_GROUP", fmt.Sprintf("%s-arc-data", inputResourcePrefix))
	if os.Getenv("ARC_DATA_LOCATION") == "" {
		os.Setenv("ARC_DATA_LOCATION", "eastasia")
	}
	os.Setenv("CONNECTED_CLUSTER", fmt.Sprintf("%s%s", inputResourcePrefix, "aks"))
	os.Setenv("ARC_DATA_EXT", "arc-data-bootstrapper")
	os.Setenv("ARC_DATA_EXT_AUTO_UPGRADE", "false")
	if os.Getenv("ARC_DATA_EXT_VERSION") == "" {
		t.Fatalf("You must specify the bootstrapper extension version explicitly, e.g. ARC_DATA_EXT_VERSION=1.2.19831003")
	}
	os.Setenv("ARC_DATA_NAMESPACE", "azure-arc-data")
	os.Setenv("ARC_DATA_CONTROLLER", "azure-arc-data-controller")
	if os.Getenv("ARC_DATA_CONTROLLER_LOCATION") == "" {
		os.Setenv("ARC_DATA_CONTROLLER_LOCATION", "southeastasia")
	}
	os.Setenv("DELETE_FLAG", "false")
}

// Retrieves the Azure Arc Connected Cluster Get response
func getConnectedClusterProperties(t *testing.T, ctx context.Context, cred azcore.TokenCredential, resourceGroupName, clusterName string) *armhybridkubernetes.ConnectedClusterClientGetResponse {
	connectedClusterClient, err := armhybridkubernetes.NewConnectedClusterClient(os.Getenv("AZURE_SUBSCRIPTION_ID"), cred, nil)
	require.NoError(t, err)

	clusterResponse, err := connectedClusterClient.Get(
		ctx,
		resourceGroupName,
		clusterName,
		nil,
	)
	require.NoError(t, err)

	return &clusterResponse
}

// Retrieves list of Azure Arc Connected Cluster Extensions
func getConnectedClusterExtension(t *testing.T, ctx context.Context, cred azcore.TokenCredential, resourceGroupName, clusterName, extensionName string) *armkubernetesconfiguration.ExtensionsClientGetResponse {
	extensionClient, err := armkubernetesconfiguration.NewExtensionsClient(os.Getenv("AZURE_SUBSCRIPTION_ID"), cred, nil)
	require.NoError(t, err)

	extensionResponse, err := extensionClient.Get(
		ctx,
		resourceGroupName,
		"Microsoft.Kubernetes",
		"connectedClusters",
		clusterName,
		extensionName,
		nil,
	)
	require.NoError(t, err)

	return &extensionResponse
}

// Retreieves Custom Location
func getCustomLocation(t *testing.T, ctx context.Context, cred azcore.TokenCredential, resourceGroupName, customLocationName string) *armextendedlocation.CustomLocationsClientGetResponse {
	customLocationClient, err := armextendedlocation.NewCustomLocationsClient(os.Getenv("AZURE_SUBSCRIPTION_ID"), cred, nil)
	require.NoError(t, err)

	customLocationResponse, err := customLocationClient.Get(
		ctx,
		resourceGroupName,
		customLocationName,
		nil,
	)
	require.NoError(t, err)

	return &customLocationResponse
}

// Retreieves Data Controller
func getDataController(t *testing.T, ctx context.Context, cred azcore.TokenCredential, resourceGroupName, dataControllerName string) *armazurearcdata.DataControllersClientGetDataControllerResponse {
	dataControllerClient, err := armazurearcdata.NewDataControllersClient(os.Getenv("AZURE_SUBSCRIPTION_ID"), cred, nil)
	require.NoError(t, err)

	dataControllerResponse, err := dataControllerClient.GetDataController(
		ctx,
		resourceGroupName,
		dataControllerName,
		nil,
	)
	require.NoError(t, err)

	return &dataControllerResponse
}
