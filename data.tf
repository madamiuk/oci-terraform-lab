data "oci_identity_availability_domains" "ads" {
  compartment_id = "ocid1.tenancy.oc1..aaaaaaaadmtufspqmm6zoiip5gpos7feuur4ls3znevb2efz6dwhimo4nsqq"
}

data "oci_core_vcns" "ansible_lab" {
  compartment_id = "ocid1.tenancy.oc1..aaaaaaaadmtufspqmm6zoiip5gpos7feuur4ls3znevb2efz6dwhimo4nsqq"
  display_name   = "ansible-lab-vcn"
}

data "oci_core_subnets" "ansible_public" {
  compartment_id = "ocid1.tenancy.oc1..aaaaaaaadmtufspqmm6zoiip5gpos7feuur4ls3znevb2efz6dwhimo4nsqq"
  display_name   = "ansible-public-subnet"
}
