SHELL       := /usr/bin/env bash
ENV         ?= dev
TF_DIR      := infra/terraform/envs/$(ENV)
APP_DIR     := app
CHART_DIR   := k8s/charts/api
IMAGE       ?= cloud-platform-blueprint/api
TAG         ?= local
VENV        := $(APP_DIR)/.venv

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'

## ---------- Application ----------
.PHONY: app-install app-test app-lint app-run
app-install: ## Create venv and install app + dev dependencies
	python3 -m venv $(VENV)
	$(VENV)/bin/pip install -U pip
	$(VENV)/bin/pip install -r $(APP_DIR)/requirements.txt -r $(APP_DIR)/requirements-dev.txt

app-test: ## Run unit tests with coverage
	cd $(APP_DIR) && .venv/bin/pytest

app-lint: ## Lint & format-check Python
	cd $(APP_DIR) && .venv/bin/ruff check . && .venv/bin/ruff format --check .

app-run: ## Run the API locally on :8080
	cd $(APP_DIR) && .venv/bin/uvicorn src.main:app --reload --port 8080

## ---------- Docker ----------
.PHONY: docker-build docker-run docker-scan
docker-build: ## Build the container image
	docker build -t $(IMAGE):$(TAG) $(APP_DIR)

docker-run: ## Run the container image on :8080
	docker run --rm -p 8080:8080 --read-only --tmpfs /tmp $(IMAGE):$(TAG)

docker-scan: ## Scan the image with Trivy
	trivy image --severity HIGH,CRITICAL --exit-code 1 $(IMAGE):$(TAG)

## ---------- Terraform ----------
.PHONY: tf-fmt tf-init tf-validate tf-plan tf-apply tf-destroy
tf-fmt: ## Format all Terraform code
	terraform fmt -recursive infra/terraform

tf-init: ## terraform init for ENV (needs TF_STATE_BUCKET)
	terraform -chdir=$(TF_DIR) init -backend-config="bucket=$${TF_STATE_BUCKET:?set TF_STATE_BUCKET}"

tf-validate: ## terraform validate for ENV
	terraform -chdir=$(TF_DIR) validate

tf-plan: ## terraform plan for ENV
	terraform -chdir=$(TF_DIR) plan -out=tfplan

tf-apply: ## terraform apply the saved plan for ENV
	terraform -chdir=$(TF_DIR) apply tfplan

tf-destroy: ## terraform destroy ENV (asks for confirmation)
	terraform -chdir=$(TF_DIR) destroy

## ---------- Kubernetes ----------
.PHONY: helm-lint helm-template policy-test
helm-lint: ## Lint the Helm chart
	helm lint $(CHART_DIR) -f $(CHART_DIR)/values.yaml -f $(CHART_DIR)/values-$(ENV).yaml

helm-template: ## Render chart to rendered/$(ENV).yaml
	mkdir -p rendered
	helm template api $(CHART_DIR) -f $(CHART_DIR)/values-$(ENV).yaml > rendered/$(ENV).yaml

policy-test: helm-template ## Check rendered manifests against OPA policies
	conftest test rendered/$(ENV).yaml -p policies/conftest

## ---------- Misc ----------
.PHONY: pre-commit
pre-commit: ## Run all pre-commit hooks
	pre-commit run --all-files
