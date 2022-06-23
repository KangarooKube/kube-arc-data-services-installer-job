package test

import (
	"bytes"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

// Terratest uses Kubernetes 1.13 which doesn't have Kustomize: https://github.com/gruntwork-io/terratest/blob/0dd0f81e8cee879995a10660f6e084d9334a8e53/go.sum#L1350
// This is a workaround to generate the kustomized manifests for k8s.KubectlApply instead
// This requires kubectl on the local machine

// kustomizePath - path to the kustomize manifest directory
// payloadPath - path to the directory where the kustomized manifest will be written
func generateKustomizedManifest(t *testing.T, kustomizePath, payloadPath string) string {
	args := []string{"kustomize", kustomizePath}
	cmd := exec.Command("kubectl", args...)

	// Call Kustomize in command line
	var outb, errb bytes.Buffer
	cmd.Stdout = &outb
	cmd.Stderr = &errb

	err := cmd.Run()
	require.NoError(t, err)

	// Append timestamp to payloadPath
	timestamp := time.Now().Unix()
	payloadPath = fmt.Sprintf("%s-%d", payloadPath, timestamp)

	// Create directory if not exists
	createDirIfNotExist(t, payloadPath)

	// Write Kustomize Payload to a file: $payloadPath/payload.yaml
	kustomizedManifestPath := filepath.Join(payloadPath, "payload.yaml")

	err = ioutil.WriteFile(kustomizedManifestPath, outb.Bytes(), 0644)
	require.NoError(t, err)

	// We return the whole folder since Kubectl can act on a folder
	return payloadPath
}

// If directory does not exist, create it
func createDirIfNotExist(t *testing.T, dir string) {
	if _, err := os.Stat(dir); os.IsNotExist(err) {
		err := os.MkdirAll(dir, 0755)
		require.NoError(t, err)
	}
}

// Delete the directory and all its contents if exists
func deleteDir(t *testing.T, dir string) {
	if _, err := os.Stat(dir); err == nil {
		err := os.RemoveAll(dir)
		require.NoError(t, err)
	}
}

// Replaces values in a given file into a new file as per the given map
// templateFilePath - full path to template file
// payloadFilePath - full path to payload file
func generateTemplate(t *testing.T, templateFilePath, payloadFilePath string, replacements map[string]string) {
	input, err := ioutil.ReadFile(templateFilePath)
	require.NoError(t, err)

	// Loop over map and grab key value pairs
	output := input
	for key, value := range replacements {
		output = bytes.Replace(output, []byte(key), []byte(value), -1)
	}

	err = ioutil.WriteFile(payloadFilePath, output, 0666)
	require.NoError(t, err)
}
