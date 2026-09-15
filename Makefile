TF_DIR := terraform
VM_NAME := legacy-tomcat

LOCALSTACK_ENDPOINT := http://localhost:4566
AWS_ENV := AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1

ANSIBLE_DIR := ansible
ANSIBLE_INVENTORY ?= $(ANSIBLE_DIR)/inventories/generated/hosts.ini
ANSIBLE_VENV ?= $(HOME)/.venvs/ansible
ANSIBLE := $(ANSIBLE_VENV)/bin/ansible
ANSIBLE_PLAYBOOK := $(ANSIBLE_VENV)/bin/ansible-playbook

APP_VERSION ?=
CONFIG_VERSION ?=
APP_ENV ?= qa

.PHONY: init fmt validate plan apply destroy state providers \
	s3-ls secrets-ls localstack-health \
	vm-list vm-start vm-info vm-cloud-init vm-user vm-python vm-check \
	ansible-ping ansible-setup ansible-setup-check \
	deploy app-artifacts config-artifacts tomcat-status \
	gitea-logs runner-logs

init:
	terraform -chdir=$(TF_DIR) init

fmt:
	terraform -chdir=$(TF_DIR) fmt -recursive

validate:
	terraform -chdir=$(TF_DIR) validate

plan:
	terraform -chdir=$(TF_DIR) plan

apply:
	terraform -chdir=$(TF_DIR) apply

destroy:
	terraform -chdir=$(TF_DIR) destroy

state:
	terraform -chdir=$(TF_DIR) state list

providers:
	terraform -chdir=$(TF_DIR) providers

localstack-health:
	curl -fsS $(LOCALSTACK_ENDPOINT)/_localstack/health

s3-ls:
	$(AWS_ENV) aws --endpoint-url=$(LOCALSTACK_ENDPOINT) s3 ls

secrets-ls:
	$(AWS_ENV) aws --endpoint-url=$(LOCALSTACK_ENDPOINT) secretsmanager list-secrets

app-artifacts:
	@test -n "$(APP_VERSION)" || (echo "APP_VERSION is required. Example: make app-artifacts APP_VERSION=2.0.4"; exit 1)
	$(AWS_ENV) aws --endpoint-url=$(LOCALSTACK_ENDPOINT) s3 ls s3://legacy-artifacts/legacy-tomcat-demo/$(APP_VERSION)/

config-artifacts:
	@test -n "$(CONFIG_VERSION)" || (echo "CONFIG_VERSION is required. Example: make config-artifacts CONFIG_VERSION=1.0.2"; exit 1)
	$(AWS_ENV) aws --endpoint-url=$(LOCALSTACK_ENDPOINT) s3 ls s3://legacy-artifacts/legacy-tomcat-demo-config/$(CONFIG_VERSION)/

vm-list:
	multipass list

vm-start:
	multipass start $(VM_NAME)

vm-info:
	multipass info $(VM_NAME)

vm-cloud-init:
	multipass exec $(VM_NAME) -- cloud-init status --wait

vm-user:
	multipass exec $(VM_NAME) -- id ansible

vm-python:
	multipass exec $(VM_NAME) -- python3 --version

vm-check: vm-list vm-cloud-init vm-user vm-python

ansible-ping:
	$(ANSIBLE) -i $(ANSIBLE_INVENTORY) app_servers -m ping

ansible-setup:
	$(ANSIBLE_PLAYBOOK) -i $(ANSIBLE_INVENTORY) $(ANSIBLE_DIR)/playbooks/setup.yml

ansible-setup-check:
	$(ANSIBLE_PLAYBOOK) -i $(ANSIBLE_INVENTORY) $(ANSIBLE_DIR)/playbooks/setup.yml --check --diff

deploy:
	@test -n "$(APP_VERSION)" || (echo "APP_VERSION is required. Example: make deploy APP_VERSION=2.0.4 CONFIG_VERSION=1.0.2 APP_ENV=qa"; exit 1)
	@test -n "$(CONFIG_VERSION)" || (echo "CONFIG_VERSION is required. Example: make deploy APP_VERSION=2.0.4 CONFIG_VERSION=1.0.2 APP_ENV=qa"; exit 1)
	$(AWS_ENV) $(ANSIBLE_PLAYBOOK) \
		-i $(ANSIBLE_INVENTORY) \
		$(ANSIBLE_DIR)/playbooks/deploy.yml \
		-e app_version=$(APP_VERSION) \
		-e config_version=$(CONFIG_VERSION) \
		-e app_environment=$(APP_ENV)

tomcat-status:
	$(ANSIBLE) -i $(ANSIBLE_INVENTORY) app_servers -b -m ansible.builtin.command -a "systemctl is-active tomcat"

gitea-logs:
	docker logs --tail=100 -f legacy-lab-gitea

runner-logs:
	docker logs --tail=100 -f legacy-lab-gitea-runner
