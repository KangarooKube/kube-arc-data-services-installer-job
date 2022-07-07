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

create-new-release:
	$(AT)echo ""
	$(AT)echo " Creating new release.env file "
	$(AT)echo ""
	$(AT)make -C release create-new-release

# Platform specific variables
#
SHELL := /bin/bash
ROOT_DIR := $(realpath $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))/..)

# Print help information to the console.
#
help:
	@echo ""
	@echo "Release: "
	@echo "   make create-new-release                  - Interactive prompts for create a new release.env file."
	@echo "   make clean-dos2unix                      - Before running a release, runs dos2unix to clean up in case of CRLF related pains."
	@echo "   make help                                - This help text."
	@echo ""
