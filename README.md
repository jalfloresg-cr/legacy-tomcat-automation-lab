# Legacy Tomcat Automation Lab

Local lab for modernizing a traditional Java/Tomcat deployment workflow without redesigning or containerizing the application.

The project separates infrastructure provisioning, server bootstrap, configuration management, application configuration, secrets, and application deployment.

## Architecture

```text
Developer
   |
   +--> Application Repository
   |        |
   |        +--> Build WAR
   |        +--> Publish versioned artifact
   |                         |
   |                         v
   |                        S3
   |
   +--> Configuration Repository
            |
            +--> Versioned application.properties.j2
                              |
                              v

                         Deployment Pipeline
                              |
                              v
                           Ansible
                          /       \
                         /         \
                  WAR from S3   Config from Git
                         \         /
                          \       /
                       Resolve Secrets
                              |
                              v
                       Render Properties
                              |
                              v
                         Tomcat Server
```

## Infrastructure Abstraction

The compute layer is now isolated behind a Terraform module.

```text
                        Root Terraform
                              |
                              v
                        module.compute
                              |
                 +------------+------------+
                 |                         |
              Current                    Future
                 |                         |
                 v                         v
             Multipass               AWS / Azure
                 |
                 v
          Common compute outputs
          ----------------------
          name
          host
          ssh_user
          ssh_port
                 |
                 v
              Ansible
```

The goal is that Ansible does not care whether the target server is a Multipass VM, an AWS EC2 instance, an Azure VM, or another Linux server reachable over SSH.

## Tool Responsibilities

```text
Terraform
   |
   +--> LocalStack
   |      +--> S3
   |      +--> Secrets Manager
   |
   +--> Compute module
          |
          +--> Multipass adapter
                 |
                 +--> Ubuntu VM
                 +--> cloud-init bootstrap

cloud-init
   |
   +--> Create ansible user
   +--> Install SSH public key
   +--> Configure passwordless sudo
   +--> Install Python 3

Ansible
   |
   +--> Java 21
   +--> Apache Tomcat
   +--> Application directories
   +--> Versioned WAR deployment
   +--> Versioned external configuration
   +--> Secret resolution
   +--> Health checks
   +--> Rollback
```

Terraform provisions infrastructure.

Cloud-init performs only the minimal first-boot bootstrap required to make the server manageable.

Ansible will configure the application server and perform application deployments.

## Current Status

Completed:

- [x] Terraform installed and initialized
- [x] Docker provider configured
- [x] LocalStack running with Docker
- [x] S3 bucket created: `legacy-artifacts`
- [x] Secrets Manager enabled
- [x] Application secret resource created
- [x] Multipass installed
- [x] Ubuntu 24.04 VM provisioned by Terraform
- [x] cloud-init bootstrap
- [x] `ansible` SSH user
- [x] Passwordless sudo
- [x] Python 3 in the target VM
- [x] Ansible installed on the host
- [x] `amazon.aws` Ansible collection installed
- [x] Multipass compute implementation moved into a reusable Terraform module
- [x] Existing Terraform state migrated into the module without recreating the VM
- [x] Compute module exposes a provider-independent contract

Next:

- [ ] Generate the Ansible inventory from the compute module outputs
- [ ] Validate Ansible connectivity with `ansible -m ping`
- [ ] Install Java 21 with Ansible
- [ ] Install Apache Tomcat with Ansible
- [ ] Publish the first WAR artifact to S3
- [ ] Checkout versioned application configuration from Git
- [ ] Resolve secrets at deployment time
- [ ] Render `application.properties`
- [ ] Deploy the WAR
- [ ] Run health checks
- [ ] Add rollback support
- [ ] Add CI/CD pipeline

## Repository Structure

```text
legacy-tomcat-automation-lab/
├── .gitignore
├── README.md
├── Makefile
└── terraform/
    ├── .terraform.lock.hcl
    ├── versions.tf
    ├── providers.tf
    ├── variables.tf
    ├── compute.tf
    ├── migrations.tf
    ├── localstack.tf
    ├── s3.tf
    ├── secrets.tf
    └── modules/
        └── compute/
            └── multipass/
                ├── main.tf
                ├── variables.tf
                ├── outputs.tf
                ├── templates/
                │   └── cloud-init.yaml.tftpl
                └── scripts/
                    └── multipass_info.py
```

Generated local files such as `terraform/cloud-init.generated.yaml` are intentionally excluded from Git.

## Compute Contract

The Multipass implementation exposes a small common interface:

```text
name
host
ssh_user
ssh_port
```

For the current local lab:

```text
Multipass
   |
   +--> name     = legacy-tomcat
   +--> host     = VM IPv4 address
   +--> ssh_user = ansible
   +--> ssh_port = 22
```

A future AWS implementation could expose the same contract using an EC2 public or private IP.

A future Azure implementation could expose the same contract using an Azure VM IP.

This keeps the deployment automation independent from the infrastructure provider.

## Terraform State Migration

The VM originally existed in the root module.

After moving the compute implementation into `module.compute`, Terraform resource addresses changed.

Example:

```text
Before:
terraform_data.multipass_vm

After:
module.compute.terraform_data.multipass_vm
```

The `migrations.tf` file uses Terraform `moved` blocks so the state can follow the refactor without destroying and recreating the VM.

Example:

```hcl
moved {
  from = terraform_data.multipass_vm
  to   = module.compute.terraform_data.multipass_vm
}
```

Once all relevant Terraform state has been migrated, these migration blocks may eventually be removed.

## Prerequisites

The host machine requires:

- Terraform
- Docker
- Docker Compose
- Multipass
- AWS CLI
- Git
- Python 3
- OpenSSH
- Ansible
- SSH key pair

The current Ansible environment also uses:

```text
amazon.aws
boto3
botocore
```

## Terraform Commands

The root Makefile wraps the most common commands.

```bash
make init
make fmt
make validate
make plan
make apply
make state
make providers
```

Destroy the lab:

```bash
make destroy
```

## LocalStack

LocalStack is exposed at:

```text
http://localhost:4566
```

The lab uses dummy AWS credentials:

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
```

List buckets:

```bash
make s3-ls
```

List Secrets Manager resources:

```bash
make secrets-ls
```

## S3 Artifact Repository

Application artifacts will use versioned paths.

```text
s3://legacy-artifacts/
└── legacy-tomcat-demo/
    ├── 1.0.0/
    │   ├── legacy-tomcat-demo.war
    │   └── legacy-tomcat-demo.war.sha256
    └── 1.1.0/
        ├── legacy-tomcat-demo.war
        └── legacy-tomcat-demo.war.sha256
```

Ansible will later receive the requested application version and download exactly that artifact.

## Secrets Manager

Terraform creates the secret resource:

```text
legacy-tomcat-demo/qa/application
```

Terraform intentionally does not manage the actual secret value.

This prevents the password from being intentionally placed in the Terraform configuration or managed as part of the lab's Terraform state.

The deployment process will resolve the value at runtime.

## Multipass VM

The current local compute implementation creates an Ubuntu 24.04 VM.

Example:

```text
Name:   legacy-tomcat
CPU:    2
Memory: 2G
Disk:   10G
```

The VM intentionally starts without Java or Tomcat.

Those belong to Ansible.

## cloud-init

The Multipass module renders a cloud-init template and supplies it during VM creation.

cloud-init performs only:

```text
Create ansible user
        |
Install SSH public key
        |
Configure sudo
        |
Install Python 3
        |
VM ready for Ansible
```

It does not install Java, Tomcat, or the application.

## Planned Ansible Deployment

The target command will eventually look similar to:

```bash
ansible-playbook playbooks/deploy.yml \
  -e environment=qa \
  -e app_version=1.0.0 \
  -e config_version=v1.0.0
```

The deployment flow will be:

```text
Select application version
        |
Download WAR from S3
        |
Verify checksum
        |
Checkout configuration version
        |
Resolve secrets
        |
Render application.properties
        |
Backup current deployment
        |
Deploy configuration
        |
Deploy WAR
        |
Restart Tomcat
        |
Health check
```

## Goal

The application can remain a traditional Java WAR deployed to Tomcat while its delivery process becomes versioned, repeatable, automated, and infrastructure-provider independent.

> Legacy application does not have to mean legacy delivery process.
