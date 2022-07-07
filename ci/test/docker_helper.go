package test

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"io"
	"testing"
	"time"

	// Docker Client
	"github.com/docker/docker/api/types"
	"github.com/docker/docker/client"
	"github.com/docker/docker/pkg/archive"

	// Terragrunt
	"github.com/gruntwork-io/terratest/modules/logger"

	// Testing
	"github.com/stretchr/testify/require"
)

type ErrorLine struct {
	Error       string      `json:"error"`
	ErrorDetail ErrorDetail `json:"errorDetail"`
}

type ErrorDetail struct {
	Message string `json:"message"`
}

// Build image from local Dockerfile and Tag it
func imageBuildTag(t *testing.T, dockerClient *client.Client, dockerFilePath, tag string, buildArgs map[string]string) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Minute*15) // Long context to support debugging
	defer cancel()

	tar, err := archive.TarWithOptions(dockerFilePath, &archive.TarOptions{})
	require.NoError(t, err)

	// Convert buildArgs from map[string]string to map[string]*string
	buildArgsPtr := make(map[string]*string, len(buildArgs))

	// Convert buildArgs map to a slice so we can create a pointer
	temp := []string{}
	i := 0
	for k, v := range buildArgs {
		temp = append(temp, v)
		buildArgsPtr[k] = &temp[i]
		i++
	}

	// Print all pairs being passed into buildArgs
	logger.Log(t, "Received the following buildArgs from envfile: \n")
	for k, v := range buildArgsPtr {
		logger.Logf(t, "%s:%s", k, *v)
	}

	opts := types.ImageBuildOptions{
		Dockerfile: "Dockerfile",
		NoCache:    true,
		Tags:       []string{tag},
		BuildArgs:  buildArgsPtr,
		Remove:     true,
	}
	res, err := dockerClient.ImageBuild(ctx, tar, opts)
	require.NoError(t, err)

	defer res.Body.Close()

	err = print(t, res.Body)
	require.NoError(t, err)
}

// Pushes image to a private registry - returns error for assertion
func imagePush(t *testing.T, dockerClient *client.Client, authConfigEncoded, tag string) error {
	ctx, cancel := context.WithTimeout(context.Background(), time.Minute*15) // Long context to support debugging
	defer cancel()

	opts := types.ImagePushOptions{RegistryAuth: authConfigEncoded}
	rd, err := dockerClient.ImagePush(ctx, tag, opts)
	require.NoError(t, err)

	defer rd.Close()

	err = print(t, rd)
	require.NoError(t, err)

	return nil
}

// Prints output of Docker process
func print(t *testing.T, rd io.Reader) error {
	var lastLine string

	scanner := bufio.NewScanner(rd)
	for scanner.Scan() {
		lastLine = scanner.Text()
		logger.Log(t, scanner.Text())
	}

	errLine := &ErrorLine{}
	json.Unmarshal([]byte(lastLine), errLine)

	if errLine.Error != "" {
		return errors.New(errLine.Error)
	}

	if err := scanner.Err(); err != nil {
		return err
	}

	return nil
}
