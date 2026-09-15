# Legacy Tomcat Automation Lab

Local lab for modernizing a traditional Java/Tomcat deployment workflow without redesigning or containerizing the application.

## Architecture

```text
Application Repo ──> WAR ──> S3
                         \
Config Repo ─────────────> Ansible ──> Tomcat VM
                              ^
                              |
                       Secrets Manager
```

## Responsibilities

- **Terraform** provisions the local lab infrastructure.
- **LocalStack** simulates AWS S3 and Secrets Manager.
- **Multipass** will provide the Ubuntu VM representing the application server.
- **Ansible** will install Java/Tomcat and deploy the versioned WAR and configuration.

## Current Infrastructure

Terraform currently manages:

- LocalStack Docker image/container
- S3 bucket: `legacy-artifacts`
- Secrets Manager secret: `legacy-tomcat-demo/qa/application`

## Prerequisites

- Terraform
- Docker
- Multipass
- AWS CLI
- Git
- Python 3
- SSH

## Repository Structure

```text
legacy-tomcat-automation-lab/
├── README.md
├── Makefile
└── terraform/
    ├── versions.tf
    ├── providers.tf
    ├── localstack.tf
    ├── s3.tf
    └── secrets.tf
```

## Terraform Commands

```bash
make init
make fmt
make validate
make plan
make apply
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

The AWS CLI uses dummy credentials:

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
```

List buckets:

```bash
make s3-ls
```

List secrets:

```bash
make secrets-ls
```

## Planned Artifact Layout

```text
s3://legacy-artifacts/
└── legacy-tomcat-demo/
    └── 1.0.0/
        ├── legacy-tomcat-demo.war
        └── legacy-tomcat-demo.war.sha256
```

## Secrets

Terraform creates the secret resource but does not store the actual password value in the Terraform configuration.

The deployment process will resolve secrets at runtime and inject them into the versioned `application.properties.j2` template.

## Next Phase

- Create the Multipass Ubuntu VM with Terraform.
- Generate the Ansible inventory.
- Install Java 21 and Tomcat with Ansible.
- Download the requested WAR version from S3.
- Checkout the requested configuration version from Git.
- Resolve secrets and render `application.properties`.
- Deploy, restart, health-check, and later add rollback.

> Legacy application does not have to mean legacy delivery process.
