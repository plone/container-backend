## Defensive settings for make:
#     https://tech.davis-hansson.com/p/make/
SHELL:=bash
.ONESHELL:
.SHELLFLAGS:=-xeu -o pipefail -O inherit_errexit -c
.SILENT:
.DELETE_ON_ERROR:
MAKEFLAGS+=--warn-undefined-variables
MAKEFLAGS+=--no-builtin-rules

# We like colors
# From: https://coderwall.com/p/izxssa/colored-makefile-for-golang-projects
RED=`tput setaf 1`
GREEN=`tput setaf 2`
RESET=`tput sgr0`
YELLOW=`tput setaf 3`

# Current version
MAIN_IMAGE_NAME=plone/plone-backend
CLASSICUI_IMAGE_NAME=plone/plone-classicui
BASE_IMAGE_NAME=plone/server
PLONE_VERSION=$$(cat version.txt)
PYTHON_VERSION=3.12
IMAGE_TAG=${PLONE_VERSION}

# Code Quality
CURRENT_FOLDER=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
CODE_QUALITY_VERSION=2.1.1
ifndef LOG_LEVEL
	LOG_LEVEL=INFO
endif
CURRENT_USER=$$(whoami)
USER_INFO=$$(id -u ${CURRENT_USER}):$$(getent group ${CURRENT_USER}|cut -d: -f3)
LINT=docker run --rm -e LOG_LEVEL="${LOG_LEVEL}" -v "${CURRENT_FOLDER}":/github/workspace plone/code-quality:${CODE_QUALITY_VERSION} check
FORMAT=docker run --rm --user="${USER_INFO}" -e LOG_LEVEL="${LOG_LEVEL}" -v "${CURRENT_FOLDER}":/github/workspace plone/code-quality:${CODE_QUALITY_VERSION} format



.PHONY: all
all: help

# Add the following 'help' target to your Makefile
# And add help text after each target name starting with '\#\#'
.PHONY: help
help: # This help message
	@grep -E '^[a-zA-Z_-]+:.*?# .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?# "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# Format
.PHONY: format
format: ## Format the codebase according to our standards
	@echo "$(GREEN)==> Format Python helper$(RESET)"
	$(FORMAT)

.PHONY: lint
lint: ## check code style
	$(LINT)

# Build image
.PHONY: show-image
show-image: ## Print Version
	@echo "$(MAIN_IMAGE_NAME):$(IMAGE_TAG)"
	@echo "$(BASE_IMAGE_NAME)-(builder|dev|prod-config|acceptance):$(IMAGE_TAG)"
	@echo "$(CLASSICUI_IMAGE_NAME):$(IMAGE_TAG)"

.PHONY: image-builder
image-builder:  ## Build Base Image
	@echo "Building $(BASE_IMAGE_NAME)-builder:$(IMAGE_TAG)"
	@docker buildx build . --no-cache --build-arg PLONE_VERSION=${PLONE_VERSION} --build-arg PYTHON_VERSION=${PYTHON_VERSION} -t $(BASE_IMAGE_NAME)-builder:$(IMAGE_TAG) -f Dockerfile.builder --load

.PHONY: image-dev
image-dev:  ## Build Dev Image
	@echo "Building $(BASE_IMAGE_NAME)-dev:$(IMAGE_TAG)"
	@docker buildx build . --no-cache --build-arg PLONE_VERSION=${PLONE_VERSION} --build-arg PYTHON_VERSION=${PYTHON_VERSION} -t $(BASE_IMAGE_NAME)-dev:$(IMAGE_TAG) -f Dockerfile.dev --load

.PHONY: image-prod-config
image-prod-config:  ## Build Prod Image
	@echo "Building $(BASE_IMAGE_NAME)-prod-config:$(IMAGE_TAG)"
	@docker buildx build . --no-cache --build-arg PLONE_VERSION=${PLONE_VERSION} --build-arg PYTHON_VERSION=${PYTHON_VERSION} -t $(BASE_IMAGE_NAME)-prod-config:$(IMAGE_TAG) -f Dockerfile.prod --load

.PHONY: image-classicui
image-classicui:  ## Build Classic UI
	@echo "Building $(CLASSICUI_IMAGE_NAME):$(IMAGE_TAG)"
	@docker buildx build . --no-cache --build-arg PLONE_VERSION=${PLONE_VERSION} --build-arg PYTHON_VERSION=${PYTHON_VERSION} -t $(CLASSICUI_IMAGE_NAME):$(IMAGE_TAG) -f Dockerfile.classicui --load

.PHONY: image-acceptance
image-acceptance:  ## Build Acceptance Image
	@echo "Building $(BASE_IMAGE_NAME)-acceptance:$(IMAGE_TAG)"
	@docker buildx build . --no-cache --build-arg PLONE_VERSION=${PLONE_VERSION} --build-arg PYTHON_VERSION=${PYTHON_VERSION} -t $(BASE_IMAGE_NAME)-acceptance:$(IMAGE_TAG) -f Dockerfile.acceptance --load

.PHONY: image-main
image-main:  ## Build main image
	@echo "Building $(MAIN_IMAGE_NAME):$(IMAGE_TAG)"
	@docker buildx build . --no-cache --build-arg PLONE_VERSION=${PLONE_VERSION} --build-arg PYTHON_VERSION=${PYTHON_VERSION} -t $(MAIN_IMAGE_NAME):$(IMAGE_TAG) -f Dockerfile --load

.PHONY: build-images
build-images:  ## Build Images
	@echo "Building $(BASE_IMAGE_NAME)-(builder|dev|prod):$(IMAGE_TAG) images"
	$(MAKE) image-builder
	$(MAKE) image-dev
	$(MAKE) image-prod-config
	$(MAKE) image-acceptance
	@echo "Building $(MAIN_IMAGE_NAME):$(IMAGE_TAG)"
	$(MAKE) image-main
	@echo "Building $(CLASSICUI_IMAGE_NAME):$(IMAGE_TAG)"
	$(MAKE) image-classicui

create-tag: # Create a new tag using git
	@echo "Creating new tag $(PLONE_VERSION)"
	if git show-ref --tags v$(PLONE_VERSION) --quiet; then echo "$(PLONE_VERSION) already exists";else git tag -a v$(PLONE_VERSION) -m "Release $(PLONE_VERSION)" && git push && git push --tags;fi

.PHONY: remove-tag
remove-tag: # Remove an existing tag locally and remote
	@echo "Removing tag v$(IMAGE_TAG)"
	if git show-ref --tags v$(IMAGE_TAG) --quiet; then git tag -d v$(IMAGE_TAG) && git push origin :v$(IMAGE_TAG) && echo "$(IMAGE_TAG) removed";else echo "$(IMAGE_TAG) does not exist";fi

.PHONY: towncrier
towncrier: # Put news snippets in the changelog for the new version
	@echo "Gathering news snippets for $(PLONE_VERSION)"
	towncrier build --version=$(PLONE_VERSION)
	@echo "If this looks right, you can call 'make commit-and-release'"

commit-and-release: # Commit new version change and create tag
	@echo "Commiting changes"
	@git commit -am "Use Plone $(PLONE_VERSION)"
	make create-tag
