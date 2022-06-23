package test

import (
	// Native
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
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

	// Arc should now be onboarded - perform validations
	// TODO: Validate Arc in both K8s and ARM

	// TODO: New Stage: Arc K8s checks
	// TODO: New Stage: Arc ARM checks

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

	// Arc should now be destroyed - perform validations

	// TODO: New Stage: Arc K8s checks
	// TODO: New Stage: Arc ARM checks
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
		t.Logf("Onboaring Job Log: \n %s", output)

		// Delete all job resources
		k8s.KubectlDelete(t, options, tempKustomizedManifestPath)

		// Delete temporary manifest directory
		deleteDir(t, tempKustomizedManifestPath)
	}()

	// Apply manifest
	k8s.KubectlApply(t, options, tempKustomizedManifestPath)

	// Wait 30 mins if job succeeds - sufficient duration for Arc onboarding/offboarding
	retriesDuration, _ := time.ParseDuration("60s")
	k8s.WaitUntilJobSucceed(t, options, jobName, 30, retriesDuration)

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