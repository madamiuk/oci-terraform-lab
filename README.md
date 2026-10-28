# OCI Terraform Lab

Terraform laboratory for managing an existing Oracle Cloud Infrastructure environment used for Ansible, monitoring and application deployment exercises.

The project was created by importing an already running OCI laboratory into Terraform and then gradually refactoring the configuration into reusable Infrastructure as Code.

## Architecture

The current OCI environment consists of:

- VCN: `ansible-lab-vcn`
- Public subnet: `ansible-public-subnet`
- Internet Gateway
- Default Route Table
- Default Security List
- Three ARM Compute instances based on `VM.Standard.A1.Flex`

Current instances:

| Instance | Role | Private IP |
|---|---|---|
| `oci-ansible01` | WildFly / application server | `10.10.1.37` |
| `oci-ansible02` | Nagios monitoring server | `10.10.1.176` |
| `oci-ansible03` | PostgreSQL database server | `10.10.1.26` |

All three instances use:

- Oracle Linux 9
- `VM.Standard.A1.Flex`
- 1 OCPU
- 6 GB RAM
- the same SSH public key
- public IPv4 addresses
- the same OCI availability domain

The instances are distributed across separate fault domains.

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
- relationships between OCI resources

### Ansible

Ansible manages the operating-system and service configuration after infrastructure provisioning.

Examples include:

- WildFly
- PostgreSQL
- Nagios
- NRPE
- firewall configuration inside guest systems
- application deployment
- monitoring plugins and service configuration

### Applications

Applications such as JobTracker are maintained in separate repositories and deployed onto infrastructure configured by Terraform and Ansible.

The intended long-term workflow is:

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
Application deployment
```

## Repository structure

Typical repository layout:

```text
oci-terraform-lab/
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

### `versions.tf`

Defines:

- required Terraform version
- OCI Terraform provider
- provider version constraints

### `provider.tf`

Configures the OCI provider.

Authentication uses the local OCI CLI configuration profile:

```text
~/.oci/config
```

The region is supplied through a Terraform variable.

### `network.tf`

Manages:

- VCN
- public subnet
- Internet Gateway
- route table
- security list

Terraform resource references are used instead of hardcoded OCIDs wherever possible.

For example:

```hcl
route_table_id = oci_core_route_table.ansible_lab_default.id
```

and:

```hcl
security_list_ids = [
  oci_core_security_list.ansible_lab_default.id
]
```

### `compute.tf`

Compute instances are managed with a single `oci_core_instance` resource using `for_each`.

Example:

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

This avoids maintaining multiple nearly identical resource blocks.

### `locals.tf`

Contains derived and shared configuration values.

The Compute instance map contains host-specific parameters such as:

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

Network security rules reference these values instead of duplicating IP addresses.

### `variables.tf`

Declares environment-specific Terraform variables such as:

- OCI region
- compartment OCID
- availability domain
- VCN CIDR
- subnet CIDR
- Compute shape
- Compute image OCID

### `terraform.tfvars`

Contains the real values for the current OCI environment.

This file is intentionally excluded from Git.

### `terraform.tfvars.example`

Provides a safe template for creating the local `terraform.tfvars`.

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

## Terraform state

The Terraform state is stored locally.

State files are excluded from Git:

```text
*.tfstate
*.tfstate.*
```

Terraform state may contain infrastructure identifiers and other environment information and must not be committed to the repository.

## OCI authentication

Terraform uses the OCI CLI configuration stored outside the repository.

Typical location:

```text
/Users/ma/.oci/config
```

The OCI API private key is also stored outside the repository.

Neither the OCI configuration nor private keys must ever be committed to Git.

## SSH authentication

The Compute instances use the local SSH public key:

```text
/Users/ma/.ssh/id_ed25519.pub
```

Terraform reads the key with:

```hcl
ssh_authorized_keys = trimspace(file(local.ssh_public_key_file))
```

`trimspace()` is intentional.

During import testing, using the raw `file()` value introduced a newline difference in instance metadata, which caused Terraform to plan replacement of the instance.

## Safety controls

Existing infrastructure was imported rather than recreated.

Critical resources use:

```hcl
lifecycle {
  prevent_destroy = true
}
```

This is especially important for imported Compute instances.

During the initial Compute import Terraform detected a metadata difference and planned:

```text
-/+ destroy and then create replacement
```

`prevent_destroy` blocked the operation.

No `terraform apply` should be executed when the plan contains unexpected:

```text
+
-
-/+
```

for existing infrastructure.

## Standard workflow

Initialize the project:

```bash
terraform init
```

Format configuration:

```bash
terraform fmt
```

Validate configuration:

```bash
terraform validate
```

Review infrastructure differences:

```bash
terraform plan
```

The expected state after a successful import or refactor is:

```text
No changes. Your infrastructure matches the configuration.
```

Only after reviewing the plan should infrastructure changes be applied:

```bash
terraform apply
```

## Import methodology

The existing OCI environment was adopted incrementally.

Each resource followed the same process:

```text
1. Describe the existing OCI resource in HCL
2. terraform fmt
3. terraform validate
4. terraform import
5. terraform plan
6. Require a zero-drift plan
7. Commit the verified milestone
```

Resources were imported in approximately this order:

```text
VCN
 |
 +-- Subnet
 |
 +-- Internet Gateway
 |
 +-- Route Table
 |
 +-- Security List
 |
 +-- oci-ansible01
 +-- oci-ansible02
 +-- oci-ansible03
```

No Terraform `apply` was used to recreate the existing imported infrastructure.

## Compute state refactoring

Initially the three Compute instances had separate Terraform resource addresses:

```text
oci_core_instance.oci_ansible01
oci_core_instance.oci_ansible02
oci_core_instance.oci_ansible03
```

After introducing `for_each`, their state addresses were migrated with `terraform state mv` to:

```text
oci_core_instance.ansible["oci-ansible01"]
oci_core_instance.ansible["oci-ansible02"]
oci_core_instance.ansible["oci-ansible03"]
```

This allowed the HCL structure to be refactored without recreating any OCI instance.

## Network security

The OCI Security List currently includes rules for laboratory services including:

- SSH
- ICMP
- NRPE
- WildFly
- PostgreSQL

Host-specific rules reuse Compute IP definitions from `local.compute_instances`.

This reduces duplicated configuration and ensures that related infrastructure values remain consistent.

## Git policy

The repository tracks Terraform source code and dependency lock information.

Tracked examples:

```text
*.tf
.terraform.lock.hcl
terraform.tfvars.example
README.md
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

Real credentials, API private keys and local Terraform state must never be committed.

## Current status

The existing OCI infrastructure has been successfully imported and refactored.

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

After the latest refactoring:

```bash
terraform validate
```

returns a valid configuration and:

```bash
terraform plan
```

returns:

```text
No changes. Your infrastructure matches the configuration.
```

## Planned development

Possible next steps for the laboratory include:

- improve Terraform outputs
- generate data useful for Ansible inventory
- reduce remaining environment-specific constants
- evaluate remote Terraform state
- introduce GitHub Actions validation
- integrate Terraform and Ansible workflows
- provision additional laboratory hosts using Terraform
- use Terraform outputs as input to automated configuration and deployment pipelines

The long-term goal is a reproducible infrastructure workflow:

```text
GitHub
   |
   v
Terraform
   |
   v
OCI
   |
   v
Ansible
   |
   v
WildFly / PostgreSQL / Nagios
   |
   v
Applications
```
