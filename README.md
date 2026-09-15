# Legacy Tomcat Automation Lab

A local lab for modernizing the delivery of a traditional Java WAR running on Apache Tomcat without requiring the application to be containerized or redesigned.

The project separates infrastructure provisioning, first-boot bootstrap, server configuration, CI/CD, application artifacts, external configuration, secrets, and deployment.

> Legacy application does not have to mean legacy delivery process.

## Architecture

```text
Application Repository --tag--> Gitea Actions --WAR + SHA256--------+
                                                                    |
Configuration Repository --tag--> Gitea Actions --config + SHA256---+--> LocalStack S3
                                                                    |
                                                                    v
                                                            Ansible Controller
                                                               /         \
                                                              /           \
                                                        S3 artifacts   Secrets Manager
                                                              \           /
                                                               \         /
                                                                v       v
                                                            Verify + Render
                                                                  |
                                                                  v
                                                            Tomcat Server
                                                                  |
                                                                  v
                                                         /actuator/health
                                                                  |
                                                                  v
                                                                 UP
```

## Design Principles

1. **Terraform is optional for existing infrastructure.** It provisions the local lab, but Ansible can target any reachable Linux server.
2. **cloud-init performs only minimal bootstrap.**
3. **Ansible owns server configuration and application deployment.**
4. **Application and configuration releases are independently versioned.**
5. **CI creates immutable release artifacts; it does not deploy them.**
6. **Artifacts are verified with SHA-256 before deployment.**
7. **Secrets are resolved at deployment time and are not stored in Git or release artifacts.**
8. **Tomcat is stopped only when the WAR changes and restarted only when configuration/runtime settings require it.**
9. **Repeated deployment of the same desired state is idempotent.**

## Infrastructure Modes

### Provisioned local lab

```text
Terraform
   |
   +--> Docker
   |     +--> LocalStack
   |     +--> Gitea
   |     +--> Gitea Actions Runner
   |
   +--> Multipass compute module
          |
          +--> Ubuntu 24.04 VM
                 |
                 +--> cloud-init
                 +--> generated Ansible inventory
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

Terraform can be skipped when infrastructure already exists.

## Compute Abstraction

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
Ansible inventory
```

Ansible does not need to know which infrastructure provider created the server.

## Tool Responsibilities

```text
Terraform
   +--> LocalStack
   +--> S3 bucket
   +--> Secrets Manager resource
   +--> Gitea / runner
   +--> Multipass VM
   +--> generated inventory

cloud-init
   +--> ansible user
   +--> SSH key
   +--> passwordless sudo
   +--> Python 3

Gitea Actions
   +--> build/test WAR
   +--> validate configuration
   +--> generate SHA-256
   +--> publish versioned releases to S3

Ansible
   +--> Java 21
   +--> Apache Tomcat 11
   +--> artifact downloads
   +--> SHA-256 validation
   +--> secret resolution
   +--> external configuration rendering
   +--> controlled WAR deployment
   +--> application work-cache cleanup
   +--> conditional Tomcat stop/start/restart
   +--> health checks
```

## Repository Structure

```text
legacy-tomcat-automation-lab/
├── .gitignore
├── ansible.cfg
├── Makefile
├── README.md
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
│   ├── gitea.tf
│   ├── gitea-runner.tf
│   ├── templates/
│   │   ├── hosts.ini.tftpl
│   │   └── gitea-runner-config.yaml
│   └── modules/
│       └── compute/
│           └── multipass/
│               ├── main.tf
│               ├── variables.tf
│               ├── outputs.tf
│               ├── templates/cloud-init.yaml.tftpl
│               └── scripts/multipass_info.py
└── ansible/
    ├── inventories/
    │   ├── generated/hosts.ini
    │   └── examples/hosts.ini.example
    ├── playbooks/
    │   ├── setup.yml
    │   └── deploy.yml
    └── roles/
        ├── java/
        ├── tomcat/
        └── application/
            ├── defaults/main.yml
            ├── tasks/main.yml
            └── templates/setenv.sh.j2
```

Generated inventory and rendered bootstrap files are intentionally excluded from Git.

## Related Repositories

```text
legacy-tomcat-demo-app
legacy-tomcat-demo-config
legacy-tomcat-automation-lab
```

The application and configuration repositories are also hosted in local Gitea for the CI/CD portion of the lab.

## Prerequisites

The host requires Terraform, Docker, Multipass, AWS CLI, Git, Python 3, OpenSSH, and Ansible.

Ansible lives in:

```bash
source ~/.venvs/ansible/bin/activate
```

The environment uses `amazon.aws`, `boto3`, and `botocore`.

The Makefile invokes `~/.venvs/ansible/bin/ansible*` directly, so activating the virtualenv is optional when using `make`.

## Terraform and VM

```bash
make init
make fmt
make validate
make plan
make apply

make vm-start
make vm-info
make vm-check
```

Terraform generates:

```text
ansible/inventories/generated/hosts.ini
```

Validate connectivity:

```bash
make ansible-ping
```

Use existing infrastructure by overriding the inventory:

```bash
make ansible-ping ANSIBLE_INVENTORY=/path/to/customer/hosts.ini
```

## Server Setup

```bash
make ansible-setup
```

Best-effort setup check mode:

```bash
make ansible-setup-check
```

Current runtime:

```text
Ubuntu 24.04
Java 21
Apache Tomcat 11.0.25
```

## LocalStack

LocalStack provides S3 and Secrets Manager at `http://localhost:4566`.

```bash
make localstack-health
make s3-ls
make secrets-ls
```

Terraform creates the secret resource but does not manage its value.

Example:

```bash
AWS_ACCESS_KEY_ID=test \
AWS_SECRET_ACCESS_KEY=test \
AWS_DEFAULT_REGION=us-east-1 \
aws --endpoint-url=http://localhost:4566 \
  secretsmanager put-secret-value \
  --secret-id legacy-tomcat-demo/qa/application \
  --secret-string '{"db_username":"legacy_user","db_password":"change-me"}'
```

For a real environment, use the organization's approved secret injection process instead of a literal command-line value.

## CI/CD with Gitea Actions

Gitea simulates an internal CI platform. The same design can be implemented with GitHub Actions, GitLab CI, Jenkins, Azure DevOps, or another CI system.

### Application release

A tag such as `v2.0.4` publishes:

```text
s3://legacy-artifacts/legacy-tomcat-demo/2.0.4/
├── legacy-tomcat-demo.war
└── legacy-tomcat-demo.war.sha256
```

```bash
make app-artifacts APP_VERSION=2.0.4
```

### Configuration release

A tag such as `v1.0.2` publishes:

```text
s3://legacy-artifacts/legacy-tomcat-demo-config/1.0.2/
├── config.tar.gz
└── config.tar.gz.sha256
```

```bash
make config-artifacts CONFIG_VERSION=1.0.2
```

Templates retain secret placeholders:

```properties
spring.datasource.username={{ app_secrets.db_username }}
spring.datasource.password={{ app_secrets.db_password }}
application.environment={{ app_environment }}
application.version={{ app_version }}
```

The rendered `application.properties` exists only on the target server.

## Deployment

The deployment requires `app_version`, `config_version`, and `app_environment`.

```bash
make deploy \
  APP_VERSION=2.0.4 \
  CONFIG_VERSION=1.0.2 \
  APP_ENV=qa
```

Flow:

```text
Secrets Manager
      |
Download WAR + checksum
      |
Verify SHA-256
      |
Download config + checksum
      |
Verify SHA-256
      |
Extract environment template
      |
Render /opt/legacy-demo/config/application.properties
      |
Render Tomcat setenv.sh
      |
Compare desired and deployed WAR
      |
      +---------------------------+
      |                           |
    changed                    unchanged
      |                           |
Stop Tomcat                      |
Copy WAR                         |
Remove exploded app              |
Clear app work cache             |
Start Tomcat                     |
      |                           |
      +-------------+-------------+
                    |
        restart only if config/setenv changed
                    |
             health check -> UP
```

Tomcat `setenv.sh` exposes:

```bash
export SPRING_CONFIG_ADDITIONAL_LOCATION="file:/opt/legacy-demo/config/"
```

## Controlled Tomcat Changes

| Change | Tomcat behavior |
| --- | --- |
| WAR changed | Stop -> deploy -> remove exploded app/work cache -> start |
| Only config or `setenv.sh` changed | Restart |
| Nothing changed | No restart |

The application-specific work cache is:

```text
/opt/tomcat/current/work/Catalina/localhost/legacy-tomcat-demo
```

## Health Check and Idempotency

The deployment waits for:

```text
GET /legacy-tomcat-demo/actuator/health
```

A validated run returned:

```text
Application deployed successfully
Application version: 2.0.4
Configuration version: 1.0.2
Environment: qa
Health status: UP
```

Running the same deployment again produced no Tomcat restart:

```text
WAR changed: false
Configuration changed: false
Tomcat environment changed: false
```

## Useful Make Targets

```bash
make init
make fmt
make validate
make plan
make apply

make localstack-health
make s3-ls
make secrets-ls

make vm-start
make vm-info
make vm-check

make ansible-ping
make ansible-setup
make ansible-setup-check

make app-artifacts APP_VERSION=2.0.4
make config-artifacts CONFIG_VERSION=1.0.2

make deploy APP_VERSION=2.0.4 CONFIG_VERSION=1.0.2 APP_ENV=qa
make tomcat-status

make gitea-logs
make runner-logs
```

## Current Status

Completed:

- [x] Terraform local infrastructure
- [x] Multipass compute abstraction
- [x] cloud-init bootstrap
- [x] generated and existing inventory modes
- [x] Java 21 automation
- [x] Apache Tomcat 11.0.25 automation
- [x] LocalStack S3 and Secrets Manager
- [x] local Gitea and Actions runner
- [x] application CI release pipeline
- [x] configuration CI release pipeline
- [x] versioned WAR/config + SHA-256 publication
- [x] runtime secret resolution
- [x] external `application.properties` rendering
- [x] Tomcat `setenv.sh`
- [x] controlled WAR deployment
- [x] application-specific work-cache cleanup
- [x] conditional Tomcat restart
- [x] health check
- [x] deployment idempotency verified

Next:

- [ ] persist LocalStack state across container recreation
- [ ] add automatic rollback on failed health checks
- [ ] optionally add deployment from CI/CD
- [ ] test the same Ansible roles against another infrastructure provider
- [ ] write the final blog article

## Goal

The application remains a traditional Java WAR deployed to Apache Tomcat, but the delivery process is now versioned, reproducible, integrity-checked, secret-aware, automated, health-validated, idempotent, and independent from the infrastructure provider.
