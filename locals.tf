locals {
  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain

  compute_shape = var.compute_shape

  compute_image_id = var.compute_image_id

  ssh_public_key_file = "/Users/ma/.ssh/id_ed25519.pub"

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

  vcn_cidr           = var.vcn_cidr
  public_subnet_cidr = var.public_subnet_cidr
}
