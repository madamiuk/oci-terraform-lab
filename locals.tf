locals {
  compartment_id      = "ocid1.tenancy.oc1..aaaaaaaadmtufspqmm6zoiip5gpos7feuur4ls3znevb2efz6dwhimo4nsqq"
  availability_domain = "ceVm:EU-FRANKFURT-1-AD-1"

  compute_shape = "VM.Standard.A1.Flex"

  compute_image_id = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaahm3jhogohzsazvoegxxow2d6gk3ys2czqokwa6y4sgw4mlxmcnsa"

  ssh_public_key_file = "/Users/ma/.ssh/id_ed25519.pub"
}
