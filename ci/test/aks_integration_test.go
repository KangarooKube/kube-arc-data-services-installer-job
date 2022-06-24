package test

import (
	// Native
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
	"time"

	// Terragrunt
	"github.com/gruntwork-io/terratest/modules/azure"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"

	// Testing
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	// Docker
	"github.com/docker/docker/api/types"
	"github.com/docker/docker/client"
)

const (
	aksTfModuleDir          = "../terraform/aks-rbac" // Relative path to the AKS terraform module
	k8sBasePayloadDir       = "../../kustomize/base"
	k8sAksOverlayPayloadDir = "../../kustomize/overlays/aks"
	k8sPayloadTempDir       = "../../kustomize/.temp"
	containerName           = "kube-arc-data-services-installer-job"
	containerVersion        = "0.1.0" // Pass this in as an env variable with the Git commit hash instead
	dockerFilePath          = "../../"
	namePrefix              = "arcCIAksTf"
	deploymentLocation      = "canadacentral"
	jobNamespace            = "azure-arc-kubernetes-bootstrap"
	jobName                 = "azure-arc-kubernetes-bootstrap"
	arcInstallTimeOutInMins = 45
)

// Test run that has skippable stages built in
func TestAksIntegrationWithStages(t *testing.T) {
	t.Parallel()

	// Set environment variables for ARM authentication
	setARMVariables(t)

	defer test_structure.RunTestStage(t, "teardown_aks", func() {
		aksTfOpts := test_structure.LoadTerraformOptions(t, aksTfModuleDir)
		defer terraform.Destroy(t, aksTfOpts)
	})

	test_structure.RunTestStage(t, "deploy_aks", func() {
		aksTfOpts := createaksTfOpts(t, aksTfModuleDir)

		// Save data to disk so that other test stages executed at a later time can read the data back in
		test_structure.SaveTerraformOptions(t, aksTfModuleDir, aksTfOpts)

		terraform.InitAndApply(t, aksTfOpts)
	})

	test_structure.RunTestStage(t, "validate_aks", func() {
		aksTfOpts := test_structure.LoadTerraformOptions(t, aksTfModuleDir)
		validateNodeCountWithARM(t, aksTfOpts)
	})

	test_structure.RunTestStage(t, "build_and_push_image", func() {
		aksTfOpts := test_structure.LoadTerraformOptions(t, aksTfModuleDir)
		buildTagPushDockerImage(t, aksTfOpts)
	})

	test_structure.RunTestStage(t, "onboard_arc", func() {
		aksTfOpts := test_structure.LoadTerraformOptions(t, aksTfModuleDir)

		// Environment variables will be converted into ConfigMap and Secret by Kustomize
		setArcJobVariables(t, aksTfOpts)

		// Run job in Onboard mode
		os.Setenv("DELETE_FLAG", "false")
		t.Logf("Running Job with DELETE_FLAG: %s", os.Getenv("DELETE_FLAG"))
		tempKustomizedManifestPath := generateTemplateAndManifest(t, aksTfOpts)
		t.Log("Deployable manifests in temp folder here:", tempKustomizedManifestPath)

		// Apply Kustomize Payload and check job health - deletes the job and the temporary manifest folder
		runJobWithK8s(t, aksTfOpts, tempKustomizedManifestPath)
	})

	test_structure.RunTestStage(t, "validate_arc_onboarding", func() {
		aksTfOpts := test_structure.LoadTerraformOptions(t, aksTfModuleDir)
		setArcJobVariables(t, aksTfOpts) // Used during tests

		validateArcOnboardedWithK8s(t, aksTfOpts)
		validateConnectedClusterWithARM(t, aksTfOpts)
		validateDataServicesWithARM(t, aksTfOpts)
	})

	test_structure.RunTestStage(t, "destroy_arc", func() {
		aksTfOpts := test_structure.LoadTerraformOptions(t, aksTfModuleDir)

		// Environment variables will be converted into ConfigMap and Secret by Kustomize
		setArcJobVariables(t, aksTfOpts)

		// Run job in Destroy mode
		os.Setenv("DELETE_FLAG", "true")
		t.Logf("Running Job with DELETE_FLAG: %s", os.Getenv("DELETE_FLAG"))
		tempKustomizedManifestPath := generateTemplateAndManifest(t, aksTfOpts)
		t.Log("Deployable manifests in temp folder here:", tempKustomizedManifestPath)

		// Apply Kustomize Payload and check job health - deletes the job and the temporary manifest folder
		runJobWithK8s(t, aksTfOpts, tempKustomizedManifestPath)
	})

	test_structure.RunTestStage(t, "validate_arc_offboarding", func() {
		aksTfOpts := test_structure.LoadTerraformOptions(t, aksTfModuleDir)
		setArcJobVariables(t, aksTfOpts) // Used during tests

		validateArcOffboardedWithK8s(t, aksTfOpts)
	})
}

// Creates Terraform Options with remote state backend
func createaksTfOpts(t *testing.T, terraformDir string) *terraform.Options {
	uniqueId := strings.ToLower(random.UniqueId())

	// State backend environment variables
	stateBlobAccountNameForTesting := GetRequiredEnvVar(t, TerraformStateBlobStoreNameForTestEnvVarName)
	stateBlobAccountContainerForTesting := GetRequiredEnvVar(t, TerraformStateBlobStoreContainerForTestEnvVarName)
	stateBlobAccountKeyForTesting := GetRequiredEnvVar(t, TerraformStateBlobStoreKeyForTestEnvVarName)

	storageAccountStateKey := fmt.Sprintf("%s/%s/terraform.tfstate", t.Name(), uniqueId)

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

		BackendConfig: map[string]interface{}{
			"storage_account_name": stateBlobAccountNameForTesting,
			"container_name":       stateBlobAccountContainerForTesting,
			"access_key":           stateBlobAccountKeyForTesting,
			"key":                  storageAccountStateKey,
		},

		// Service Principal creds from Environment Variables
		EnvVars: setTerraformVariables(t),

		// Colors in Terraform commands - we like colors
		NoColor: false,
	}
}

// Validate that the Node Count is g.t.e 3 for Arc Data deployment
func validateNodeCountWithARM(t *testing.T, aksTfOpts *terraform.Options) {
	inputResourcePrefix := aksTfOpts.Vars["resource_prefix"].(string)

	// This is defined in our module
	expectedResourceGroupName := fmt.Sprintf("%s%s", inputResourcePrefix, "rg")
	expectedClusterName := fmt.Sprintf("%s%s", inputResourcePrefix, "aks")

	// Look up the cluster node count from ARM
	cluster, err := azure.GetManagedClusterE(t, expectedResourceGroupName, expectedClusterName, "")
	require.NoError(t, err)
	actualCount := *(*cluster.ManagedClusterProperties.AgentPoolProfiles)[0].Count
	t.Logf("Found cluster with %d nodes", actualCount)

	t.Run("aks_node_count_greater_than_equals_three", func(t *testing.T) {
		assert.GreaterOrEqual(t, int32(actualCount), int32(0), "AKS Node Count >= 3")
	})
}

func buildTagPushDockerImage(t *testing.T, aksTfOpts *terraform.Options) {
	// Grab Container Registry variables
	acrName := terraform.Output(t, aksTfOpts, "acr_name")
	tag := fmt.Sprintf("%s.azurecr.io/%s:%s", acrName, containerName, containerVersion)

	// Docker Client
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	require.NoError(t, err)

	// Build image from repo's Dockerfile, tag to ACR
	imageBuildTag(t, cli, dockerFilePath, tag)

	// Push image to ACR
	var authConfig = types.AuthConfig{
		Username:      os.Getenv("spnClientId"),
		Password:      os.Getenv("spnClientSecret"),
		ServerAddress: fmt.Sprintf("%s.azurecr.io/", acrName),
	}
	authConfigBytes, _ := json.Marshal(authConfig)
	authConfigEncoded := base64.URLEncoding.EncodeToString(authConfigBytes)

	err = imagePush(t, cli, authConfigEncoded, tag)

	t.Run("ensure_docker_push_successful", func(t *testing.T) {
		assert.Empty(t, err, "Docker push to ACR successful")
	})
}

// Deploys Kubernetes Deployable manifests via Kustomize
func generateTemplateAndManifest(t *testing.T, aksTfOpts *terraform.Options) string {

	// Replace placeholders in Kustomize manifest
	replacements := make(map[string]string)
	replacements["${IMAGE_REGISTRY}"] = fmt.Sprintf("%s.azurecr.io", terraform.Output(t, aksTfOpts, "acr_name"))
	replacements["${IMAGE_TAG}"] = containerVersion

	templatePath, err := filepath.Abs(k8sBasePayloadDir)
	require.NoError(t, err)
	templateFilePath := filepath.Join(templatePath, "kustomization.template.yaml")
	payloadFilePath := filepath.Join(templatePath, "kustomization.yaml")

	// Workaround for envsubst
	generateTemplate(t, templateFilePath, payloadFilePath, replacements)

	// Generate Kustomized manifest
	kustomizePath, err := filepath.Abs(k8sAksOverlayPayloadDir)
	require.NoError(t, err)
	payloadPath, err := filepath.Abs(k8sPayloadTempDir)
	require.NoError(t, err)
	tempKustomizedManifestPath := generateKustomizedManifest(t, kustomizePath, payloadPath)

	// Return Path to Kustomize Manifest
	return tempKustomizedManifestPath
}

// Apply Manifest and validate job succeeds - cleans up after itself and prints out the logs from Job run
func runJobWithK8s(t *testing.T, aksRbacOpts *terraform.Options, tempKustomizedManifestPath string) {

	// Setup the kubectl config and namespace context - grabbed from Terraform module output
	options := k8s.NewKubectlOptions("", fmt.Sprintf("%s/kubeconfig", aksTfModuleDir), jobNamespace)

	// Clean up
	defer func() {
		// Get log of Job pod and print to test output for debugging later
		// We want to run this before the deletes because if the Job fails, test will try to exit with this function
		output, err := k8s.RunKubectlAndGetOutputE(t, options, "logs", fmt.Sprintf("job/%s", jobName), "-n", jobNamespace)
		require.NoError(t, err)
		t.Logf("Job Log: \n %s", output)

		// Delete all job resources
		k8s.KubectlDelete(t, options, tempKustomizedManifestPath)

		// Delete temporary manifest directory
		deleteDir(t, tempKustomizedManifestPath)
	}()

	// Apply manifest
	k8s.KubectlApply(t, options, tempKustomizedManifestPath)

	// Wait sufficient amount of time - e.g. 45 mins - to see if job succeeds
	retriesDuration, _ := time.ParseDuration("60s")
	k8s.WaitUntilJobSucceed(t, options, jobName, arcInstallTimeOutInMins, retriesDuration)

	// Get Job status
	jobStatus := k8s.IsJobSucceeded(k8s.GetJob(t, options, jobName))

	// Publish unit test results
	if os.Getenv("DELETE_FLAG") == "false" {
		t.Run("ensure_onboarding_job_succeeded", func(t *testing.T) {
			assert.True(t, jobStatus, "Onboarding Kubernetes Job succeeded")
		})
	} else if os.Getenv("DELETE_FLAG") == "true" {
		t.Run("ensure_offboarding_job_succeeded", func(t *testing.T) {
			assert.True(t, jobStatus, "Offboarding Kubernetes Job succeeded")
		})
	} else {
		t.Fatal("DELETE_FLAG is not correctly set")
	}
}

// Calls Kubernetes to get post-deployment health checks done
func validateArcOnboardedWithK8s(t *testing.T, aksRbacOpts *terraform.Options) {
	// Namespace: "azure-arc" - which is static
	options := k8s.NewKubectlOptions("", fmt.Sprintf("%s/kubeconfig", aksTfModuleDir), "azure-arc")

	// Get Last Connectivity Time for connected cluster
	jsonPathQuery := "{.items[*]['status.lastConnectivityTime']}"
	clusterConnectTime, err := k8s.RunKubectlAndGetOutputE(t, options, "get", "connectedclusters", fmt.Sprintf("-o=jsonpath=%q", jsonPathQuery)) // %q adds quotes
	require.NoError(t, err)
	t.Logf("Last Cluster Connectivity Time (UTC): %s", clusterConnectTime)

	t.Run("k8s_ensure_cluster_connectivity_time_not_empty", func(t *testing.T) {
		assert.NotEmpty(t, clusterConnectTime, "Cluster Connectivity Time is not empty")
	})

	// Get Data Controller Health Status
	options = k8s.NewKubectlOptions("", fmt.Sprintf("%s/kubeconfig", aksTfModuleDir), os.Getenv("ARC_DATA_NAMESPACE"))

	jsonPathQuery = "{.items[*]['status']}"
	controllerStatus, err := k8s.RunKubectlAndGetOutputE(t, options, "get", "datacontrollers", fmt.Sprintf("-o=jsonpath=%q", jsonPathQuery))
	require.NoError(t, err)
	t.Logf("Controller Status: %s", controllerStatus)

	jsonPathQuery = "{.items[*]['status.state']}"
	controllerState, err := k8s.RunKubectlAndGetOutputE(t, options, "get", "datacontrollers", fmt.Sprintf("-o=jsonpath=%q", jsonPathQuery))
	require.NoError(t, err)
	controllerState = regexp.MustCompile(`^"(.*)"$`).ReplaceAllString(controllerState, `$1`) // Remove quotes
	t.Logf("Controller State: %s", controllerState)

	t.Run("k8s_ensure_controller_is_ready", func(t *testing.T) {
		assert.Equal(t, "ready", strings.ToLower(controllerState), "Controller is in Ready State")
	})

	// Get all Api Groups with Microsoft owned CRDs installed in Cluster
	microsoftApiGroups := getAllMicrosoftCrdApiGroups(t, options)

	t.Logf("All Microsoft APIGroups for CRDs installed in the Cluster: %s", microsoftApiGroups)

	t.Run("k8s_ensure_one_or_more_microsoft_crd_apigroups_installed", func(t *testing.T) {
		assert.GreaterOrEqual(t, len(microsoftApiGroups), 1, "One or more Microsoft CRD APIGroups are installed in the Cluster")
	})
}

// Function calls ARM to validate the Connected Cluster
func validateConnectedClusterWithARM(t *testing.T, aksRbacOpts *terraform.Options) {
	// Authenticate to Azure and initiate context
	cred := getAzureCred(t)
	ctx := context.Background()

	// This is defined in our module
	expectedConnectedClusterRg := os.Getenv("CONNECTED_CLUSTER_RESOURCE_GROUP")
	expectedClusterName := os.Getenv("CONNECTED_CLUSTER")

	// Get Connected Cluster Properties
	clusterProperty := getConnectedClusterProperties(t, ctx, cred, expectedConnectedClusterRg, expectedClusterName)

	t.Run("arm_ensure_cluster_connectivity_time_not_empty", func(t *testing.T) {
		assert.NotEmpty(t, *clusterProperty.ConnectedCluster.Properties.LastConnectivityTime, "Cluster Connectivity Time is not empty")
	})

	t.Run("arm_ensure_cluster_connectivity_time_is_connected", func(t *testing.T) {
		assert.Equal(t, "connected", strings.ToLower(string(*clusterProperty.ConnectedCluster.Properties.ConnectivityStatus)), "Cluster is Connected")
	})

	// Get Data Services Extension
	extensionProperty := getConnectedClusterExtension(t, ctx, cred, expectedConnectedClusterRg, expectedClusterName, os.Getenv("ARC_DATA_EXT"))

	t.Run("arm_ensure_data_service_bootstrapper_extension_is_installed", func(t *testing.T) {
		assert.Equal(t, "succeeded", strings.ToLower(string(*extensionProperty.Properties.ProvisioningState)), "Data Services Extension is installed")
	})

	t.Run("arm_ensure_is_type_data_services", func(t *testing.T) {
		assert.Equal(t, strings.ToLower("microsoft.arcdataservices"), strings.ToLower(string(*extensionProperty.Properties.ExtensionType)), "Extension is for Data Services")
	})

	t.Run("arm_ensure_data_service_bootstrapper_extension_is_not_auto_upgraded", func(t *testing.T) {
		assert.Equal(t, false, *extensionProperty.Properties.AutoUpgradeMinorVersion, "Data Services Extension Auto Upgrade is disabled")
	})

	t.Run("arm_ensure_data_service_bootstrapper_extension_matches_declared_state", func(t *testing.T) {
		assert.Equal(t, os.Getenv("ARC_DATA_EXT_VERSION"), *extensionProperty.Properties.Version, "Data Services Extension correct version is installed")
	})
}

// // Function calls ARM to validate Data Services
func validateDataServicesWithARM(t *testing.T, aksRbacOpts *terraform.Options) {
	// Authenticate to Azure and initiate context
	cred := getAzureCred(t)
	ctx := context.Background()

	// This is defined in our module
	expectedDataServiceRg := os.Getenv("ARC_DATA_RESOURCE_GROUP")
	expectedCustomLocationName := os.Getenv("ARC_DATA_NAMESPACE")
	expectedDataControllerName := os.Getenv("ARC_DATA_CONTROLLER")

	// Get Custom Location
	customLocationProperty := getCustomLocation(t, ctx, cred, expectedDataServiceRg, expectedCustomLocationName)

	t.Run("arm_ensure_custom_location_namespace_matches_kubernetes", func(t *testing.T) {
		assert.Equal(t, os.Getenv("ARC_DATA_NAMESPACE"), *customLocationProperty.CustomLocation.Properties.Namespace, "Custom Location is connected to Data Services Kubernetes Namespace")
	})

	// Get Data Controller
	dataControllerProperty := getDataController(t, ctx, cred, expectedDataServiceRg, expectedDataControllerName)

	t.Run("arm_ensure_data_controller_deployment_succeeded", func(t *testing.T) {
		assert.Equal(t, "Succeeded", *dataControllerProperty.DataControllerResource.Properties.ProvisioningState, "Controller ARM Deployment Succeeded")
	})
}

// Calls Kubernetes to get post-offboarding health checks done
func validateArcOffboardedWithK8s(t *testing.T, aksRbacOpts *terraform.Options) {
	// Get all Api Groups with Microsoft owned CRDs installed in Cluster
	options := k8s.NewKubectlOptions("", fmt.Sprintf("%s/kubeconfig", aksTfModuleDir), "default")
	microsoftApiGroups := getAllMicrosoftCrdApiGroups(t, options)
	t.Logf("All Microsoft APIGroups for CRDs installed in the Cluster: %s", microsoftApiGroups)
	t.Run("k8s_ensure_all_microsoft_crd_apigroups_uninstalled", func(t *testing.T) {
		assert.LessOrEqual(t, len(microsoftApiGroups), 0, "All Microsoft CRD APIGroups are uninstalled from the Cluster")
	})
}
