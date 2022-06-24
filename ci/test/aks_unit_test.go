//go:build unit && aks

package test

import (
	// Native
	"testing"

	// Terragrunt
	"github.com/gruntwork-io/terratest/modules/terraform"

	// Testing
	"github.com/stretchr/testify/assert"
)

func TestAksResourcePlan(t *testing.T) {
	t.Parallel()
	testFolder := locateTestFolder(t)
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
