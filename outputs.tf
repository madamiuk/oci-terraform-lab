output "availability_domains" {
  value = data.oci_identity_availability_domains.ads.availability_domains[*].name
}

output "ansible_lab_vcn" {
  value = [
    for vcn in data.oci_core_vcns.ansible_lab.virtual_networks : {
      id           = vcn.id
      display_name = vcn.display_name
      cidr_blocks  = vcn.cidr_blocks
    }
  ]
}

output "ansible_public_subnet" {
  value = [
    for subnet in data.oci_core_subnets.ansible_public.subnets : {
      id           = subnet.id
      display_name = subnet.display_name
      cidr_block   = subnet.cidr_block
      vcn_id       = subnet.vcn_id
    }
  ]
}
