package test

import (
	"fmt"
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
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
