variable "region" {
  description = "OCI region"
  type        = string
  default     = "eu-frankfurt-1"
}

variable "vcn_cidr" {
  description = "CIDR block for the Ansible lab VCN"
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.10.1.0/24"
}

variable "compute_shape" {
  description = "OCI compute shape used by lab instances"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "compute_image_id" {
  description = "OCI image OCID used by lab instances"
  type        = string
  default     = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaahm3jhogohzsazvoegxxow2d6gk3ys2czqokwa6y4sgw4mlxmcnsa"
}

variable "compartment_id" {
  description = "OCI compartment OCID"
  type        = string
  default     = "ocid1.tenancy.oc1..aaaaaaaadmtufspqmm6zoiip5gpos7feuur4ls3znevb2efz6dwhimo4nsqq"
}

variable "availability_domain" {
  description = "OCI availability domain for compute instances"
  type        = string
  default     = "ceVm:EU-FRANKFURT-1-AD-1"
}
