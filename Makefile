###################################
# Copyright (c) 2022 KangarooKube
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
###################################

# Finds all .sh files in the repo and runs dos2unix on them
#
clean-dos2unix:
	$(AT)echo ""
	$(AT)echo " Converting Windows line endings to Unix line endings in all .sh files "
	$(AT)echo ""
	$(AT)find -name "*.sh" -type f -print0 | xargs -0 -n 1 -P 4 dos2unix

clean-permissions:
	$(AT)echo ""
	$(AT)echo " Changing permissions on all files "
	$(AT)echo ""
	$(AT)chmod -R 777 .

create-new-release-env:
	$(AT)echo ""
	$(AT)echo " Creating new release.env file "
	$(AT)echo ""
	$(AT)make -C release create-new-release

push-new-release-image: push-preview push-stable
push-preview:
	$(AT)$(DOCKER_PUSH) --no-cache \
						'kube-arc-data-services-installer-job' \
						'ghcr.io/kangarookube' \
						$(ROOT_DIR) \
						$(RELEASE_ROOT)/release.preview.env \
						preview \
						${CR_PAT}

push-stable:
	$(AT)$(DOCKER_PUSH) --no-cache \
						'kube-arc-data-services-installer-job' \
						'ghcr.io/kangarookube' \
						$(ROOT_DIR) \
						$(RELEASE_ROOT)/release.stable.env \
						stable \
						${CR_PAT}
clean-local-terraform-state:
	$(AT)echo ""
	$(AT)echo " Cleaning up State files from Terraform CI run "
	$(AT)echo ""
	$(AT)make -C ci/test clean-local-terraform-state
	@rm -rf /tmp/.terraform

clean-local-test-files: clean-local-terraform-state
	$(AT)echo ""
	$(AT)echo " Cleaning up test log files "
	$(AT)echo ""
	@rm -rf $(TEST_ROOT)/*.out
	@rm -rf $(TEST_ROOT)/*.log
	@rm -rf $(TEST_ROOT)/*.xml
	@rm -rf /tmp/TestAksIntegrationWithStages*
	@rm -rf /tmp/TestAksResourcePlan*

run-tests:
	$(AT)echo ""
	$(AT)echo " Running unit and integration tests across all release trains in parallel "
	$(AT)echo ""
	$(AT)make -j -C ci/test test

# Platform specific variables
#
SHELL                := /bin/bash
ROOT_DIR             := $(shell git rev-parse --show-toplevel)
TEST_ROOT             = $(shell git rev-parse --show-toplevel)/ci/test
KUSTOMIZE_ROOT        = $(shell git rev-parse --show-toplevel)/kustomize
RELEASE_ROOT          = $(shell git rev-parse --show-toplevel)/release
DOCKER_PUSH          := $(shell git rev-parse --show-toplevel)/release/build/docker-push.sh

# Print help information to the console.
#
help:
	@echo ""
	@echo "Release: "
	@echo "   make create-new-release-env              - Interactive prompts for create a new release.env file."
	@echo "   make push-new-release-image              - Build + Push new tagged docker images for relevant release train to ghcr.io."
	@echo "   make clean-dos2unix                      - Before running a release, runs dos2unix to clean up in case of CRLF related pains."
	@echo "   make run-tests                           - Run all tests - unit, integration, for all trains - preview, stable."
	@echo "   make clean-local-terraform-state         - Clean up State files from local CI runs."
	@echo "   make clean-local-test-files              - Clean up log files, JUnit results etc from local CI runs."
	@echo "   make clean-permissions                   - Update permissions on all files in this repo."
	@echo "   make help                                - This help text."
	@echo ""
