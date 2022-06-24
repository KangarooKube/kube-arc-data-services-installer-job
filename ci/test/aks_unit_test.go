//go:build unit && aks

package test

import (
	// Native
	"testing"

	// Terragrunt
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"

	// Testing
	"github.com/stretchr/testify/assert"
)

// Globals
var (
	// Initiate with root TF directory
	// Local run - will remain as aksTfModuleDir
	// CI run - will get overwritten with temp folder from test_structure.CopyTerraformFolderToTemp for the duration of the run
	testFolder = aksTfModuleDir
)

func TestAksResourcePlan(t *testing.T) {
	t.Parallel()

	// Set environment variables for ARM and TF authentication
	setARMVariables(t)

	// Copy the root Terraform module into a temporary directory
	testFolder = test_structure.CopyTerraformFolderToTemp(t, "../", testFolder)

	aksTfOpts := createaksTfOpts(t, testFolder)

	cnt := terraform.GetResourceCount(t, terraform.InitAndPlan(t, aksTfOpts))

	t.Run("ensure_azure_resource_add_count", func(t *testing.T) {
		assert.Equal(t, 7, cnt.Add)
	})

	t.Run("ensure_azure_resource_change_count", func(t *testing.T) {
		assert.Equal(t, 0, cnt.Change)
	})

	t.Run("ensure_azure_resource_destroy_count", func(t *testing.T) {
		assert.Equal(t, 0, cnt.Destroy)
	})
}
