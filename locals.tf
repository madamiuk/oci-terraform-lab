locals {
  compartment_id      = "ocid1.tenancy.oc1..aaaaaaaadmtufspqmm6zoiip5gpos7feuur4ls3znevb2efz6dwhimo4nsqq"
  availability_domain = "ceVm:EU-FRANKFURT-1-AD-1"

  compute_shape = "VM.Standard.A1.Flex"

  compute_image_id = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaahm3jhogohzsazvoegxxow2d6gk3ys2czqokwa6y4sgw4mlxmcnsa"

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

  vcn_cidr           = "10.10.0.0/16"
  public_subnet_cidr = "10.10.1.0/24"
}
