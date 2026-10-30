# OCI Terraform Lab

Terraform-managed Oracle Cloud Infrastructure lab used for practical infrastructure automation, Ansible integration, monitoring, and DevOps exercises.

The environment is designed to keep the OCI infrastructure reproducible and declarative while providing a realistic multi-server platform for application deployment, PostgreSQL, Nagios, CI/CD, and monitoring experiments.

## Architecture

The lab currently consists of three Oracle Linux instances running in Oracle Cloud Infrastructure in the `eu-frankfurt-1` region.

```text
                         Internet
                            |
                     Internet Gateway
                            |
                  ansible-lab-vcn
                    10.10.0.0/16
                            |
              ansible-public-subnet
                    10.10.1.0/24
                            |
          +-----------------+-----------------+
          |                 |                 |
   oci-ansible01     oci-ansible02     oci-ansible03
   Application       Monitoring         Database
   WildFly           Nagios             PostgreSQL
   JobTracker        NRPE checks        JobTracker DB
```

All compute instances use OCI Ampere A1 resources and Oracle Linux 9.

Current logical roles:

| Host | Role | Ansible groups |
|---|---|---|
| `oci-ansible01` | Application server / WildFly / JobTracker | `oci`, `appservers`, `monitored_hosts` |
| `oci-ansible02` | Nagios monitoring server | `oci`, `nagios_server` |
| `oci-ansible03` | PostgreSQL database server | `oci`, `oci_database`, `monitored_hosts` |

The application and database tiers are intentionally separated.

## Terraform-managed infrastructure

Terraform currently manages:

- OCI Virtual Cloud Network
- Public subnet
- Internet Gateway
- Route Table
- Security List
- Three Oracle Linux compute instances
- SSH key configuration
- Ansible host metadata
- OCI Notifications topic
- E-mail notification subscription
- SMS notification subscription
- OCI Monitoring alarms

Critical OCI resources use lifecycle protection where appropriate to reduce the risk of accidental destruction.

Terraform changes are always reviewed with:

```bash
terraform fmt
terraform validate
terraform plan
```

A normal fully synchronized environment should report:

```text
No changes. Your infrastructure matches the configuration.
```

## Network

VCN:

```text
10.10.0.0/16
```

Public subnet:

```text
10.10.1.0/24
```

The hosts communicate internally using their private OCI addresses.

Public addresses are intentionally not documented in this repository.

Application ports such as WildFly HTTP are not intended to be exposed directly to the Internet. Administrative access is performed over SSH and, where necessary, local SSH tunnels.

## Compute configuration

The current lab uses OCI Ampere A1 instances with approximately:

```text
1 OCPU
6 GB RAM
Oracle Linux 9
aarch64
```

The machines are distributed across fault domains where possible.

The instance definitions are maintained centrally and used as the source of metadata for both Terraform and Ansible integration.

## Ansible integration

Terraform exports host metadata through the `ansible_hosts` output.

Example:

```bash
terraform output ansible_hosts
```

The output contains:

- host name
- Ansible SSH user
- public connection address
- private OCI address
- Ansible groups

The same metadata is consumed by the Ansible inventory generation workflow.

This avoids maintaining separate hardcoded host-role mappings in Terraform and Ansible.

Conceptually:

```text
Terraform compute definition
        |
        +--> OCI instance
        |
        +--> private/public addresses
        |
        +--> Ansible groups
        |
        +--> generated Ansible inventory
```

## OCI Monitoring

OCI Monitoring provides an infrastructure-level monitoring layer independent of Nagios.

The current configuration manages **15 OCI alarms**.

### Compute alarms

Each of the three instances has:

- High CPU utilization
- High memory utilization
- High load average

This results in:

```text
3 hosts × 3 compute alarms = 9 alarms
```

Metrics are provided by the OCI Compute Agent using the `oci_computeagent` namespace.

The Oracle Cloud Agent and monitoring plugins run on all three instances.

### Health alarms

Each instance additionally has two infrastructure-health checks:

- instance accessibility
- OCI infrastructure availability

This results in:

```text
3 hosts × 2 health alarms = 6 alarms
```

The health alarms use OCI-native metrics and do not depend on the guest monitoring agent.

Total:

```text
9 compute alarms
+ 6 health alarms
-----------------
15 OCI alarms
```

## Monitoring policy

Monitoring thresholds are defined centrally and applied through Terraform without duplicating alarm resource blocks.

A common base policy exists for compute metrics, with group-specific overrides derived from the same `ansible_groups` metadata that describes the server role.

Conceptually:

```text
compute instance
      |
      +--> ansible_groups
               |
               +--> common monitoring defaults
               |
               +--> group-specific overrides
                           |
                           +--> effective alarm policy
                                      |
                                      +--> OCI Monitoring alarm
```

This allows the monitoring policy to follow the function of each server without maintaining a second host-to-role mapping.

### Default / application / monitoring server thresholds

For `appservers` and `nagios_server`:

| Metric | Warning threshold | Duration |
|---|---:|---:|
| CPU utilization | > 80% | 5 minutes |
| Memory utilization | > 85% | 5 minutes |
| Load average | > 1.5 | 5 minutes |

Severity:

```text
WARNING
```

### Database server thresholds

The PostgreSQL server uses more conservative thresholds through the `oci_database` group override:

| Metric | Warning threshold | Duration |
|---|---:|---:|
| CPU utilization | > 75% | 5 minutes |
| Memory utilization | > 80% | 5 minutes |
| Load average | > 1.2 | 5 minutes |

Severity:

```text
WARNING
```

Health and infrastructure availability alarms use:

```text
Severity: CRITICAL
Pending duration: 5 minutes
```

## DRY alarm implementation

Compute alarms are generated from a central definition map and Terraform `for_each`.

There is no separate resource block for every host and metric.

The model is approximately:

```text
alarm definitions
      |
      +--> high_cpu
      +--> high_memory
      +--> high_load
              |
              +--> host/group policy
                      |
                      +--> oci-ansible01
                      +--> oci-ansible02
                      +--> oci-ansible03
```

This allows new monitored hosts or alarm types to be added without copying entire Terraform resource definitions.

Health alarms follow the same pattern using their own definition map.

## OCI Notifications

All OCI alarms publish to one central Notifications topic:

```text
ansible-lab-alerts
```

The topic currently has two active notification channels:

```text
OCI Monitoring alarms
        |
        v
ansible-lab-alerts
        |
        +--> EMAIL
        |
        +--> SMS
```

Both endpoint values are handled as sensitive Terraform variables.

The repository does not contain the actual e-mail address or telephone number.

Example shell configuration:

```bash
export TF_VAR_notification_email='user@example.com'
export TF_VAR_notification_sms_phone='+48XXXXXXXXX'
```

Sensitive notification endpoints must never be committed to Git.

## Alarm validation

The notification pipeline was tested using a real CPU utilization alarm on `oci-ansible01`.

A controlled CPU load was generated until the OCI metric exceeded the configured threshold for the required pending duration.

The alarm successfully transitioned:

```text
OK
 |
 v
FIRING
 |
 v
OK
```

OCI reported:

```text
OK_TO_FIRING
```

and after the load was removed:

```text
FIRING_TO_OK
```

Both transitions were confirmed through OCI Monitoring alarm history.

The `FIRING` notification was successfully delivered through:

```text
EMAIL
SMS
```

The e-mail notification included the actual OCI metric query, instance dimensions, severity, alarm state, and trigger details.

This confirms the full production notification path:

```text
OCI Compute metric
        |
        v
OCI Monitoring
        |
        v
Alarm evaluation
        |
        v
OCI Notifications Topic
        |
        +--> EMAIL
        |
        +--> SMS
```

## Nagios and OCI Monitoring

The lab intentionally uses two complementary monitoring layers.

### Nagios

Nagios monitors the operating systems and application services from inside the environment.

Current checks include system metrics and service-specific checks such as:

- PING
- SSH
- load
- memory
- root filesystem
- swap
- process counts
- WildFly HTTP
- PostgreSQL process
- PostgreSQL connectivity
- PostgreSQL connection count
- PostgreSQL database size

NRPE is installed on monitored hosts and Nagios communicates with them over the private OCI network.

Nagios thresholds are parameterized in Ansible and support group-specific overrides.

### OCI Monitoring

OCI Monitoring observes the infrastructure from the cloud platform itself.

It provides:

- CPU monitoring
- memory monitoring
- load monitoring
- instance accessibility monitoring
- infrastructure-health monitoring
- external notifications through e-mail and SMS

This provides monitoring even when the guest operating system or Nagios becomes unavailable.

The two systems therefore cover different failure domains:

```text
Nagios
  |
  +--> guest OS
  +--> processes
  +--> services
  +--> application checks
  +--> database checks

OCI Monitoring
  |
  +--> cloud metrics
  +--> instance accessibility
  +--> infrastructure health
  +--> external EMAIL/SMS notification
```

## Notification topic output

Terraform exposes the Notifications topic OCID:

```bash
terraform output -raw notification_topic_id
```

This can be used for diagnostics or controlled test publication.

Manual message publication can be performed with OCI CLI:

```bash
oci ons message publish \
  --topic-id "$(terraform output -raw notification_topic_id)" \
  --title "Ansible Lab Test" \
  --body "Test OCI Notifications"
```

For SMS validation, a real OCI Monitoring alarm should be used because SMS delivery is intended for supported OCI service-generated notification scenarios.

## Security

The project follows several security rules:

- private SSH keys are never stored in the repository
- Terraform state files must not be committed
- notification e-mail addresses are not stored in tracked files
- SMS telephone numbers are not stored in tracked files
- Terraform sensitive variables are used for notification endpoints
- application secrets are managed separately through Ansible Vault
- service ports are not unnecessarily exposed to the public Internet
- internal server communication uses OCI private addresses

Always inspect:

```bash
git status
```

before committing infrastructure changes.

## Terraform state safety

Terraform state may contain sensitive infrastructure information and must remain outside Git.

Before committing:

```bash
git status
```

Verify that no files such as these are staged:

```text
terraform.tfstate
terraform.tfstate.backup
*.tfplan
tfplan.*
```

Saved Terraform plans used for controlled applies should be removed after use.

Example:

```bash
rm -f tfplan.*
```

## Typical workflow

Format and validate:

```bash
terraform fmt
terraform validate
```

Review infrastructure changes:

```bash
terraform plan
```

For important changes, save the reviewed plan:

```bash
terraform plan -out=tfplan
terraform apply tfplan
rm -f tfplan
```

Verify zero drift:

```bash
terraform plan
```

Expected result:

```text
No changes. Your infrastructure matches the configuration.
```

## CI validation

The repository contains Terraform CI validation.

The pipeline checks Terraform configuration before infrastructure changes are accepted into the main branch.

The SSH public key configuration is designed to remain portable in CI and does not depend on a workstation-specific absolute path.

## Current status

The current environment includes:

- OCI VCN and subnet managed by Terraform
- three Oracle Linux 9 instances
- Terraform-to-Ansible inventory integration
- WildFly application server
- PostgreSQL database server
- Nagios monitoring server
- JobTracker application infrastructure
- parameterized Nagios thresholds
- role-aware OCI monitoring policy
- 15 OCI Monitoring alarms
- OCI Notifications topic
- active e-mail notification channel
- active SMS notification channel
- tested `OK → FIRING → OK` alarm lifecycle
- confirmed e-mail and SMS alarm delivery
- zero Terraform drift after deployment

The lab is intended to remain reproducible, idempotent, and suitable for practical Linux administration, Ansible, Terraform, monitoring, and DevOps exercises.
