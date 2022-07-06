###################################
#
# Copyright (c) 2022 KangarooKube
#
###################################

# release.mk generates a release artifacts based on the latest available external dependencies
#

create-new-release:
	$(AT) $(ROOT_DIR)/release/build/create-new-release.sh run

create-new-release-variables: create-new-release


# Platform specific variables
#
SHELL := /bin/bash
ROOT_DIR := $(realpath $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))/..)