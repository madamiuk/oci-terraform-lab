# OCI Terraform Lab

[![Terraform CI](https://github.com/madamiuk/oci-terraform-lab/actions/workflows/terraform-ci.yml/badge.svg)](https://github.com/madamiuk/oci-terraform-lab/actions/workflows/terraform-ci.yml)

Terraform laboratory for managing an existing Oracle Cloud Infrastructure environment used by the Ansible automation and JobTracker application delivery labs.

The project was created by importing an already running OCI environment into Terraform and then gradually refactoring the configuration into reusable Infrastructure as Code.

The repository focuses on:

- adopting existing cloud infrastructure safely
- zero-drift Terraform management
- reusable Compute definitions
- network configuration
- lifecycle protection
- Terraform-to-Ansible integration
- structured Terraform outputs
- CI validation
- infrastructure safety
- separation between infrastructure and configuration management

---

## Current architecture

The current OCI environment contains:

- VCN: `ansible-lab-vcn`
- Public subnet: `ansible-public-subnet`
- Internet Gateway
- Default Route Table
- Default Security List
- Three ARM Compute instances based on `VM.Standard.A1.Flex`

Current topology:

```text
Oracle Cloud Infrastructure
│
├── VCN
│   └── ansible-lab-vcn
│       └── 10.10.0.0/16
│
├── Public subnet
│   └── ansible-public-subnet
│       └── 10.10.1.0/24
│
├── Internet Gateway
│
├── Default Route Table
│
├── Default Security List
│
└── Compute
    ├── oci-ansible01
    │   ├── Oracle Linux 9
    │   ├── WildFly
    │   └── JobTracker
    │
    ├── oci-ansible02
    │   ├── Oracle Linux 9
    │   └── Nagios
    │
    └── oci-ansible03
        ├── Oracle Linux 9
        ├── PostgreSQL 18
        └── jobtracker database
```

---

## Compute instances

Current instances:

| Instance | Role | Private IP | Fault Domain |
|---|---|---:|---|
| `oci-ansible01` | WildFly / JobTracker application server | `10.10.1.37` | `FAULT-DOMAIN-2` |
| `oci-ansible02` | Nagios monitoring server | `10.10.1.176` | `FAULT-DOMAIN-1` |
| `oci-ansible03` | PostgreSQL database server | `10.10.1.26` | `FAULT-DOMAIN-3` |

All three instances use:

- Oracle Linux 9
- `VM.Standard.A1.Flex`
- 1 OCPU
- 6 GB RAM
- ARM architecture
- the same OCI VCN and public subnet
- the same SSH public key
- public IPv4 addresses
- separate fault domains

The fault-domain distribution reduces the chance that all laboratory workloads are affected by a single fault-domain failure.

---

## Responsibility split

The laboratory intentionally separates infrastructure provisioning from operating-system and application configuration.

### Terraform

Terraform manages the OCI infrastructure layer:

- VCN
- subnet
- Internet Gateway
- route table
- security list
- Compute instances
- infrastructure relationships
- host metadata exposed through outputs

### Ansible

Ansible manages the configuration layer:

- operating system configuration
- Java
- WildFly
- PostgreSQL
- Nagios
- NRPE / monitoring agents
- firewall configuration inside guest systems
- application deployment
- runtime verification
- end-to-end tests

### JobTracker

JobTracker remains an independent application repository responsible for:

- Java application source code
- Jakarta EE
- REST API
- JPA / Hibernate
- web frontend
- application tests
- Maven build
- WAR artifact creation
- application CI

The responsibility model is:

```text
Terraform
    |
    v
OCI infrastructure
    |
    v
Ansible
    |
    v
Operating system and services
    |
    v
JobTracker deployment
```

---

## Repository integration

The OCI Terraform laboratory is part of a three-repository environment:

```text
oci-terraform-lab
        |
        +--> OCI infrastructure
        +--> Terraform outputs
        |
        v
ansible-lab
        |
        +--> generated OCI inventory
        +--> configuration management
        +--> application deployment
        +--> runtime verification
        |
        v
jobtracker
        |
        +--> application code
        +--> tests
        +--> WAR artifact
```

The repositories are intentionally independent.

This allows each layer to be tested and changed without mixing responsibilities.

---

## Terraform to Ansible integration

Terraform provides structured infrastructure metadata for Ansible.

The key integration output is:

```text
ansible_hosts
```

The output contains information required to build the OCI Ansible inventory.

Conceptually:

```text
Terraform state
      |
      v
ansible_hosts
      |
      v
Ansible inventory generator
      |
      v
inventory/oci.ini
      |
      v
Ansible
```

The Ansible repository consumes this output using:

```text
./scripts/generate-oci-inventory.sh
```

and:

```text
./scripts/refresh-oci-inventory.sh
```

This removes the need to manually maintain OCI host metadata in both Terraform and Ansible.

---

## Ansible host metadata

The Terraform output describes host roles in addition to IP addresses.

Current logical grouping includes:

```text
oci-ansible01
    groups:
        oci
        appservers
        monitored_hosts

oci-ansible02
    groups:
        oci
        nagios_server

oci-ansible03
    groups:
        oci
        oci_database
        monitored_hosts
```

This metadata is used to generate Ansible groups automatically.

The resulting inventory structure is approximately:

```ini
[oci]
oci-ansible01
oci-ansible02
oci-ansible03

[appservers]
oci-ansible01

[nagios_server]
oci-ansible02

[oci_database]
oci-ansible03

[monitored_hosts]
oci-ansible01
oci-ansible03
```

Terraform therefore provides infrastructure facts while Ansible decides how those groups are configured.

---

## Repository structure

Typical repository layout:

```text
oci-terraform-lab/
├── .github/
│   └── workflows/
│       └── terraform-ci.yml
│
├── .gitignore
├── .terraform.lock.hcl
├── README.md
├── compute.tf
├── data.tf
├── locals.tf
├── network.tf
├── outputs.tf
├── provider.tf
├── terraform.tfvars.example
├── variables.tf
└── versions.tf
```

---

## versions.tf

`versions.tf` defines:

- required Terraform version
- OCI Terraform provider
- provider version constraints

The laboratory currently uses Terraform 1.17.x and the OCI provider 9.x.

Exact provider versions are controlled through Terraform dependency constraints and:

```text
.terraform.lock.hcl
```

---

## provider.tf

The OCI provider configuration is maintained in:

```text
provider.tf
```

Authentication uses the local OCI CLI configuration.

Typical location:

```text
~/.oci/config
```

The OCI API private key is stored outside the repository.

The region is supplied through Terraform configuration rather than hardcoded into individual resources.

---

## network.tf

`network.tf` manages the OCI networking layer.

Current resources include:

```text
VCN
Public subnet
Internet Gateway
Default Route Table
Default Security List
```

Terraform resource references are used instead of hardcoded OCIDs wherever possible.

Example:

```hcl
route_table_id = oci_core_route_table.ansible_lab_default.id
```

and:

```hcl
security_list_ids = [
  oci_core_security_list.ansible_lab_default.id
]
```

This keeps dependencies explicit and reduces duplicated infrastructure identifiers.

---

## compute.tf

Compute instances are managed using a single resource definition with:

```hcl
for_each
```

Conceptually:

```hcl
resource "oci_core_instance" "ansible" {
  for_each = local.compute_instances

  compartment_id      = local.compartment_id
  availability_domain = local.availability_domain
  fault_domain        = each.value.fault_domain

  display_name = each.key
  shape        = local.compute_shape

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }
}
```

Using `for_each` avoids maintaining several nearly identical Compute resource blocks.

It also makes host-specific configuration easier to manage through:

```text
local.compute_instances
```

---

## locals.tf

`locals.tf` contains derived and shared values.

The Compute instance map contains host-specific metadata such as:

```hcl
compute_instances = {
  oci-ansible01 = {
    fault_domain = "FAULT-DOMAIN-2"
    private_ip   = "10.10.1.37"
  }

  oci-ansible02 = {
    fault_domain = "FAULT-DOMAIN-1"
    private_ip   = "10.10.1.176"
  }

  oci-ansible03 = {
    fault_domain = "FAULT-DOMAIN-3"
    private_ip   = "10.10.1.26"
  }
}
```

The same data is reused by:

- Compute resources
- network rules
- Terraform outputs
- Ansible inventory metadata

This reduces duplication and configuration drift.

---

## variables.tf

`variables.tf` declares environment-specific Terraform variables.

Examples include:

- OCI region
- compartment OCID
- availability domain
- VCN CIDR
- subnet CIDR
- Compute shape
- Compute image OCID

Environment-specific values are separated from reusable resource definitions.

---

## terraform.tfvars

The real environment values are maintained locally in:

```text
terraform.tfvars
```

This file is intentionally excluded from Git.

The repository provides:

```text
terraform.tfvars.example
```

as a safe template.

Example:

```hcl
region = "eu-frankfurt-1"

compartment_id = "ocid1.compartment.oc1..CHANGE_ME"

availability_domain = "CHANGE_ME"

vcn_cidr           = "10.10.0.0/16"
public_subnet_cidr = "10.10.1.0/24"

compute_shape = "VM.Standard.A1.Flex"

compute_image_id = "ocid1.image.oc1.eu-frankfurt-1.CHANGE_ME"
```

Real OCIDs and environment-specific values must not be committed accidentally.

---

## Terraform state

Terraform state is stored locally.

State files are excluded from Git:

```text
*.tfstate
*.tfstate.*
```

Terraform state may contain:

- infrastructure identifiers
- resource metadata
- environment topology
- sensitive implementation details

State must never be committed to the repository.

---

## OCI authentication

Terraform uses OCI API authentication configured outside the repository.

Typical configuration:

```text
~/.oci/config
```

The associated OCI API private key is also stored outside Git.

Neither the OCI configuration nor the API private key must ever be committed.

---

## SSH authentication

Compute instances use an SSH public key.

Terraform reads the public key using:

```hcl
ssh_authorized_keys = trimspace(file(local.ssh_public_key_file))
```

The use of:

```text
trimspace()
```

is intentional.

During the initial import and refactoring process, using the raw result of:

```hcl
file()
```

introduced a newline difference in instance metadata.

Terraform then interpreted the metadata change as requiring instance replacement.

Using `trimspace()` removes that unwanted difference and keeps the imported Compute resources stable.

---

## Imported infrastructure

The existing OCI environment was adopted into Terraform instead of being recreated.

The import process followed this pattern:

```text
existing OCI resource
        |
        v
describe resource in HCL
        |
        v
terraform import
        |
        v
terraform plan
        |
        v
zero-drift verification
```

Imported resources include:

```text
VCN
Public subnet
Internet Gateway
Default Route Table
Default Security List
oci-ansible01
oci-ansible02
oci-ansible03
```

This allowed the laboratory to move from manually created infrastructure to Infrastructure as Code without destroying existing systems.

---

## Import methodology

Each imported resource followed the same workflow:

```text
1. Describe the existing OCI resource in HCL
2. terraform fmt
3. terraform validate
4. terraform import
5. terraform plan
6. Require a zero-drift plan
7. Commit the verified milestone
```

The expected result after a successful import is:

```text
No changes. Your infrastructure matches the configuration.
```

A resource was not considered successfully adopted until Terraform reached zero drift.

---

## Zero-drift policy

Zero drift is treated as a core requirement.

After importing, refactoring or changing infrastructure definitions:

```bash
terraform plan
```

should return:

```text
No changes. Your infrastructure matches the configuration.
```

Unexpected changes are investigated before any apply operation.

Particular attention is paid to:

```text
+
-
-/+
```

for existing resources.

A replacement plan for an existing critical resource is treated as a warning condition, not as something to apply automatically.

---

## Safety controls

Critical imported resources use:

```hcl
lifecycle {
  prevent_destroy = true
}
```

This protects important resources from accidental destruction.

During initial Compute import work Terraform detected a metadata difference and proposed:

```text
-/+ destroy and then create replacement
```

The lifecycle protection prevented that replacement.

The configuration also ignores selected provider-managed metadata where required to prevent irrelevant drift.

Infrastructure safety is more important than forcing a Terraform apply.

---

## Terraform apply policy

The laboratory does not treat:

```bash
terraform apply
```

as a routine command to run after every edit.

The expected workflow is:

```text
terraform fmt
      |
      v
terraform validate
      |
      v
terraform plan
      |
      v
review
      |
      +--> unexpected change -> investigate
      |
      `--> expected change -> apply if required
```

For imported resources, a clean zero-drift plan remains the normal expected state.

---

## Compute state refactoring

The three Compute instances were initially imported under separate Terraform resource addresses:

```text
oci_core_instance.oci_ansible01
oci_core_instance.oci_ansible02
oci_core_instance.oci_ansible03
```

After introducing:

```hcl
for_each
```

their Terraform state addresses were migrated using:

```text
terraform state mv
```

to:

```text
oci_core_instance.ansible["oci-ansible01"]
oci_core_instance.ansible["oci-ansible02"]
oci_core_instance.ansible["oci-ansible03"]
```

This allowed the HCL structure to be refactored without recreating any Compute instance.

The change was considered complete only after:

```bash
terraform plan
```

again returned zero drift.

---

## Network security

The OCI Security List contains rules required by the laboratory infrastructure.

These include selected traffic for:

- SSH
- ICMP
- NRPE / monitoring
- WildFly internal access
- PostgreSQL internal access

Host-specific rules reuse information from:

```text
local.compute_instances
```

instead of duplicating private IP addresses throughout the Terraform configuration.

This improves consistency between Compute definitions and security rules.

---

## Application network design

JobTracker runs on:

```text
oci-ansible01
```

and PostgreSQL runs on:

```text
oci-ansible03
```

Application database traffic uses the private OCI network:

```text
WildFly
10.10.1.37
    |
    | TCP 5432
    v
PostgreSQL
10.10.1.26
```

The database is intentionally separated from the application host.

WildFly port `8080` is not intended to be generally exposed as the final public application interface.

Application access is handled separately from the Terraform Compute lifecycle.

---

## Monitoring architecture

Nagios runs on:

```text
oci-ansible02
```

The monitoring server checks the other OCI systems.

Conceptually:

```text
oci-ansible02
Nagios
    |
    +--> oci-ansible01
    |       WildFly
    |       JobTracker
    |
    +--> oci-ansible03
            PostgreSQL
```

Terraform provides the infrastructure.

Ansible configures monitoring services, plugins and host definitions.

---

## Terraform outputs

Terraform outputs are used for both human inspection and automation.

The repository exports infrastructure information such as:

- instance metadata
- IP addressing
- host roles
- Ansible group membership

The most important integration output is:

```text
ansible_hosts
```

which is consumed by the Ansible laboratory.

This turns Terraform into the authoritative source of OCI host metadata while keeping configuration management responsibilities inside Ansible.

---

## Standard workflow

Initialize the repository:

```bash
terraform init
```

Format configuration:

```bash
terraform fmt
```

Validate Terraform:

```bash
terraform validate
```

Review infrastructure state:

```bash
terraform plan
```

The preferred result for the current imported environment is:

```text
No changes. Your infrastructure matches the configuration.
```

Only when a change is intentional and fully understood should:

```bash
terraform apply
```

be considered.

---

## Terraform CI

GitHub Actions validates the Terraform repository automatically.

Workflow:

```text
.github/workflows/terraform-ci.yml
```

The CI pipeline validates the Terraform configuration without modifying OCI infrastructure.

Typical validation flow:

```text
GitHub push / pull request
        |
        v
checkout
        |
        v
Terraform setup
        |
        v
terraform fmt check
        |
        v
terraform init
        |
        v
terraform validate
```

The CI pipeline is intentionally non-destructive.

It does not automatically run:

```text
terraform apply
```

against the OCI laboratory.

Infrastructure changes therefore remain controlled and reviewable.

---

## Git policy

The repository tracks Terraform source code and dependency information.

Tracked examples:

```text
*.tf
.terraform.lock.hcl
terraform.tfvars.example
README.md
.github/workflows/
```

Ignored examples:

```text
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
*.tfvars.json
.terraformrc
terraform.rc
```

The repository must never contain:

- Terraform state
- OCI API private keys
- private SSH keys
- real secrets
- local OCI credentials

---

## Current integration workflow

The current end-to-end infrastructure/configuration relationship is:

```text
GitHub
   |
   v
Terraform CI
   |
   v
Terraform source
   |
   v
OCI infrastructure
   |
   v
Terraform outputs
   |
   v
ansible_hosts
   |
   v
Ansible inventory generation
   |
   v
Ansible configuration
   |
   +--> WildFly
   +--> PostgreSQL
   +--> Nagios
   |
   v
JobTracker deployment
   |
   v
Runtime verification
```

This integration is already operational.

It is no longer a planned future step.

---

## Current status

The current Terraform configuration manages:

```text
OCI Network
├── VCN
├── Public Subnet
├── Internet Gateway
├── Default Route Table
└── Default Security List

OCI Compute
├── oci-ansible01
├── oci-ansible02
└── oci-ansible03
```

The Compute configuration has been consolidated using:

```text
for_each
```

Terraform outputs provide host metadata to Ansible.

The repository is validated through GitHub Actions.

The imported infrastructure remains protected with lifecycle safeguards.

The normal expected Terraform plan is:

```text
No changes. Your infrastructure matches the configuration.
```

---

## Development principles

### Zero drift

Imported infrastructure should match Terraform configuration exactly.

### Review before apply

Unexpected resource changes are investigated instead of applied blindly.

### Prevent accidental destruction

Critical infrastructure uses lifecycle protection.

### Separate responsibilities

```text
Terraform -> infrastructure
Ansible   -> system configuration and deployment
JobTracker -> application behavior
```

### Do not duplicate infrastructure metadata

Shared infrastructure values should be derived from a common Terraform source where possible.

### Keep secrets outside Git

Terraform state, OCI credentials and private keys must remain local and protected.

### Prefer refactoring over recreation

Existing infrastructure should not be destroyed simply to improve Terraform code structure.

---

## Planned development

The main remaining Terraform development areas are:

- evaluate remote Terraform
