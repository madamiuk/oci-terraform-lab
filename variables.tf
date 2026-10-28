variable "region" {
  description = "OCI region"
  type        = string
}

variable "vcn_cidr" {
  description = "CIDR block for the Ansible lab VCN"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
}

variable "compute_shape" {
  description = "OCI compute shape used by lab instances"
  type        = string
}

variable "compute_image_id" {
  description = "OCI image OCID used by lab instances"
  type        = string
}

variable "compartment_id" {
  description = "OCI compartment OCID"
  type        = string
}

variable "availability_domain" {
  description = "OCI availability domain for compute instances"
  type        = string
}
