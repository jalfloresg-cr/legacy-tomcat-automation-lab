# Legacy Tomcat Automation Lab

Local lab for modernizing a traditional Java/Tomcat deployment workflow without requiring the application to be containerized or redesigned.

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

## Design Principles

1. **Terraform provisions infrastructure only when infrastructure must be created.**
2. **Ansible configures and deploys to any reachable Linux server.**
3. **Application artifacts and application configuration are versioned independently.**
4. **Secrets are resolved at deployment time and are not stored in Git.**

This allows the same Ansible automation to work with the local lab or with infrastructure that already exists.

## Infrastructure Modes

### Provisioned lab

```text
Terraform
   |
   +--> LocalStack
   |      +--> S3
   |      +--> Secrets Manager
   |
   +--> Multipass VM
          |
          v
     Generated Inventory
          |
          v
       Ansible
```

### Existing infrastructure

```text
Existing EC2 / Azure VM / VMware / Physical Server
                         |
                         v
                 Existing Inventory
                         |
                         v
                      Ansible
```

Terraform is optional when the servers already exist.

## Compute Abstraction

The local compute implementation is isolated behind a Terraform module.

```text
Root Terraform
     |
     v
module.compute
     |
     +--> Multipass today
     +--> AWS / Azure later
     |
     v
Common outputs
-------------
name
host
ssh_user
ssh_port
     |
     v
Ansible
```

Ansible does not need to know whether the target is Multipass, EC2, Azure VM, VMware, or another Linux server reachable through SSH.

## Tool Responsibilities

```text
Terraform
   +--> LocalStack
   |      +--> S3
   |      +--> Secrets Manager
   |
   +--> Compute module
          +--> Multipass VM
                 +--> cloud-init bootstrap

cloud-init
   +--> Create ansible user
   +--> Install SSH public key
   +--> Configure passwordless sudo
   +--> Install Python 3

Ansible
   +--> Java 21
   +--> Apache Tomcat
   +--> Application directories
   +--> WAR deployment
   +--> External configuration
   +--> Secret resolution
   +--> Health checks
   +--> Rollback
```

cloud-init only prepares the machine for configuration management. Java, Tomcat, and the application are managed by Ansible.

## Current Status

Completed:

- [x] Terraform initialized
- [x] Docker provider configured
- [x] LocalStack running through Docker
- [x] S3 bucket created: `legacy-artifacts`
- [x] Secrets Manager enabled
- [x] Application secret resource created
- [x] Multipass VM provisioned by Terraform
- [x] cloud-init bootstrap
- [x] `ansible` SSH user
- [x] Passwordless sudo
- [x] Python 3 available on the VM
- [x] Ansible installed locally
- [x] `amazon.aws` collection installed
- [x] Multipass encapsulated in a Terraform compute module
- [x] Terraform state migrated without recreating the VM
- [x] Generated Ansible inventory
- [x] Existing/manual inventory mode supported
- [x] Ansible connectivity validated with ping/pong
- [x] Java 21 installed through Ansible
- [x] Apache Tomcat 11.0.25 installed from the official binary archive
- [x] Tomcat configured as a systemd service
- [x] Tomcat validated running on Java 21
- [x] Safe execution and idempotency workflow documented

Next:

- [ ] Publish the first versioned WAR to S3
- [ ] Publish and verify WAR checksum
- [ ] Create the application deployment role
- [ ] Checkout versioned configuration from Git
- [ ] Resolve Secrets Manager values at deployment time
- [ ] Render `application.properties`
- [ ] Deploy the WAR to Tomcat
- [ ] Restart Tomcat only when required
- [ ] Run application health checks
- [ ] Add rollback support
- [ ] Add CI/CD pipeline

## Repository Structure

```text
legacy-tomcat-automation-lab/
├── .gitignore
├── ansible.cfg
├── README.md
├── Makefile
├── terraform/
│   ├── .terraform.lock.hcl
│   ├── versions.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── compute.tf
│   ├── migrations.tf
│   ├── inventory.tf
│   ├── localstack.tf
│   ├── s3.tf
│   ├── secrets.tf
│   ├── templates/
│   │   └── hosts.ini.tftpl
│   └── modules/
│       └── compute/
│           └── multipass/
│               ├── main.tf
│               ├── variables.tf
│               ├── outputs.tf
│               ├── templates/
│               │   └── cloud-init.yaml.tftpl
│               └── scripts/
│                   └── multipass_info.py
└── ansible/
    ├── inventories/
    │   ├── generated/
    │   │   └── hosts.ini
    │   └── examples/
    │       └── hosts.ini.example
    ├── playbooks/
    │   └── setup.yml
    └── roles/
        ├── java/
        │   └── tasks/main.yml
        └── tomcat/
            ├── defaults/main.yml
            ├── tasks/main.yml
            ├── templates/tomcat.service.j2
            └── handlers/main.yml
```

Generated files such as the Terraform-produced inventory and rendered cloud-init file are intentionally excluded from Git.

## Ansible Inventory

The lab supports both generated and existing inventories.

Terraform-generated inventory:

```text
ansible/inventories/generated/hosts.ini
```

Validate connectivity:

```bash
make ansible-ping
```

For existing infrastructure:

```ini
[app_servers]
app01 ansible_host=10.10.20.15 ansible_user=ansible ansible_port=22
app02 ansible_host=10.10.20.16 ansible_user=ansible ansible_port=22
```

Then:

```bash
make ansible-ping \
  ANSIBLE_INVENTORY=/path/to/customer/hosts.ini
```

The Ansible roles do not change.

## Safe Execution on Existing Servers

Before applying automation to an existing server, review what the playbook contains and what it would change.

List tasks without executing them:

```bash
ansible-playbook \
  ansible/playbooks/setup.yml \
  --list-tasks
```

Simulate changes:

```bash
ansible-playbook \
  ansible/playbooks/setup.yml \
  --check \
  --diff
```

Limit the dry-run to one host:

```bash
ansible-playbook \
  ansible/playbooks/setup.yml \
  --check \
  --diff \
  --limit app01
```

For additional control:

```bash
ansible-playbook \
  ansible/playbooks/setup.yml \
  --check \
  --diff \
  --step \
  --limit app01
```

`--list-tasks` does not execute the playbook against the target.

`--check` connects to the server and evaluates supported tasks without applying their changes.

Custom `command`, `shell`, or external scripts must be reviewed carefully because not every operation can be perfectly simulated in check mode.

## Idempotency

The desired behavior is convergence.

If the target already satisfies a task, Ansible reports:

```text
ok
```

If a change is required, it reports:

```text
changed
```

For example:

```yaml
- name: Install Java 21
  ansible.builtin.apt:
    name: openjdk-21-jdk
    state: present
```

If Java 21 is already installed, the task remains `ok`.

If it is missing, the task becomes `changed`.

A standard idempotency test is:

```bash
ansible-playbook ansible/playbooks/setup.yml
ansible-playbook ansible/playbooks/setup.yml
```

The second execution should ideally end with:

```text
changed=0
failed=0
```

or only known, expected changes.

This is particularly important when the automation is applied to existing customer infrastructure.

## Java

Java 21 is installed through the `java` Ansible role.

## Tomcat

Apache Tomcat is installed from the official binary archive instead of the operating system package repository.

Current lab version:

```text
Apache Tomcat 11.0.25
Java 21
```

Installation layout:

```text
/opt/tomcat/
├── apache-tomcat-11.0.25/
└── current -> apache-tomcat-11.0.25
```

Tomcat runs as a dedicated `tomcat` user through systemd.

## S3 Artifact Repository

Application artifacts will use versioned paths:

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

## Configuration Repository

Configuration is versioned separately from the WAR:

```text
legacy-tomcat-demo-config/
└── environments/
    ├── dev/
    │   └── application.properties.j2
    ├── qa/
    │   └── application.properties.j2
    └── prod/
        └── application.properties.j2
```

Sensitive values remain placeholders:

```properties
spring.datasource.username={{ app_secrets.db_username }}
spring.datasource.password={{ app_secrets.db_password }}
```

## Secrets

Terraform creates the Secrets Manager resource but does not manage the actual secret value.

The application deployment will resolve secrets at runtime and normalize them into a common structure such as:

```yaml
app_secrets:
  db_username: ""
  db_password: ""
```

## Planned Deployment Flow

```text
Application version
        |
        v
Download WAR from S3
        |
        v
Verify SHA-256
        |
        v
Checkout config version from Git
        |
        v
Resolve secrets
        |
        v
Render application.properties
        |
        v
Backup current deployment
        |
        v
Deploy configuration + WAR
        |
        v
Restart Tomcat only if needed
        |
        v
Health check
        |
        +--> Success
        |
        └--> Failure -> Rollback
```

The target deployment command will eventually look similar to:

```bash
ansible-playbook \
  ansible/playbooks/deploy.yml \
  -e environment=qa \
  -e app_version=1.0.0 \
  -e config_version=v1.0.0
```

## Goal

The application can remain a traditional Java WAR deployed to Tomcat while its delivery process becomes versioned, repeatable, automated, safer to operate, and independent from the infrastructure provider.

> Legacy application does not have to mean legacy delivery process.
