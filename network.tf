resource "oci_core_vcn" "ansible_lab" {
  compartment_id = "ocid1.tenancy.oc1..aaaaaaaadmtufspqmm6zoiip5gpos7feuur4ls3znevb2efz6dwhimo4nsqq"

  cidr_blocks = [
    "10.10.0.0/16"
  ]

  display_name = "ansible-lab-vcn"
  dns_label    = "ansiblelabvcn"

  lifecycle {
    prevent_destroy = true

    ignore_changes = [
      defined_tags
    ]
  }
}

resource "oci_core_subnet" "ansible_public" {
  compartment_id = "ocid1.tenancy.oc1..aaaaaaaadmtufspqmm6zoiip5gpos7feuur4ls3znevb2efz6dwhimo4nsqq"

  vcn_id     = oci_core_vcn.ansible_lab.id
  cidr_block = "10.10.1.0/24"

  display_name = "ansible-public-subnet"
  dns_label    = "ansiblepublicsu"

  route_table_id = "ocid1.routetable.oc1.eu-frankfurt-1.aaaaaaaawembxvrm2i47psrxwboe7ymkywewb325f5zkhhvsokkal5355daq"

  security_list_ids = [
    "ocid1.securitylist.oc1.eu-frankfurt-1.aaaaaaaa5mghzpnvbmhowyr6oqnzrioiqxqlod7jqy2kic5t63ub4wcrzs5a"
  ]

  prohibit_public_ip_on_vnic = false
  prohibit_internet_ingress  = false

  lifecycle {
    prevent_destroy = true

    ignore_changes = [
      defined_tags
    ]
  }
}

resource "oci_core_internet_gateway" "ansible_lab" {
  compartment_id = "ocid1.tenancy.oc1..aaaaaaaadmtufspqmm6zoiip5gpos7feuur4ls3znevb2efz6dwhimo4nsqq"
  vcn_id         = oci_core_vcn.ansible_lab.id

  display_name = "ansible-lab-igw"
  enabled      = true

  lifecycle {
    prevent_destroy = true

    ignore_changes = [
      defined_tags
    ]
  }
}

resource "oci_core_route_table" "ansible_lab_default" {
  compartment_id = "ocid1.tenancy.oc1..aaaaaaaadmtufspqmm6zoiip5gpos7feuur4ls3znevb2efz6dwhimo4nsqq"
  vcn_id         = oci_core_vcn.ansible_lab.id

  display_name = "Default Route Table for ansible-lab-vcn"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.ansible_lab.id
    description       = "Internet gateway for Ansible lab public subnet"
  }

  lifecycle {
    prevent_destroy = true

    ignore_changes = [
      defined_tags
    ]
  }
}

resource "oci_core_security_list" "ansible_lab_default" {
  compartment_id = "ocid1.tenancy.oc1..aaaaaaaadmtufspqmm6zoiip5gpos7feuur4ls3znevb2efz6dwhimo4nsqq"
  vcn_id         = oci_core_vcn.ansible_lab.id

  display_name = "Default Security List for ansible-lab-vcn"

  egress_security_rules {
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
    stateless        = false
  }

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = false

    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    protocol    = "1"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = false

    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    protocol    = "1"
    source      = "10.10.0.0/16"
    source_type = "CIDR_BLOCK"
    stateless   = false

    icmp_options {
      type = 3
    }
  }

  ingress_security_rules {
    description = "Allow ICMP echo within Ansible lab VCN"
    protocol    = "1"
    source      = "10.10.1.0/24"
    source_type = "CIDR_BLOCK"
    stateless   = false

    icmp_options {
      type = 8
    }
  }

  ingress_security_rules {
    description = "Allow NRPE from Nagios server"
    protocol    = "6"
    source      = "10.10.1.176/32"
    source_type = "CIDR_BLOCK"
    stateless   = false

    tcp_options {
      min = 5666
      max = 5666
    }
  }

  ingress_security_rules {
    description = "Allow WildFly [8080] for LAB"
    protocol    = "6"
    source      = "10.10.1.176/32"
    source_type = "CIDR_BLOCK"
    stateless   = false

    tcp_options {
      min = 8080
      max = 8080
    }
  }

  ingress_security_rules {
    description = "Allow PQSql"
    protocol    = "6"
    source      = "10.10.1.37/32"
    source_type = "CIDR_BLOCK"
    stateless   = false

    tcp_options {
      min = 5432
      max = 5432
    }
  }

  ingress_security_rules {
    description = "Nagios PostgreSQL monitoring"
    protocol    = "6"
    source      = "10.10.1.176/32"
    source_type = "CIDR_BLOCK"
    stateless   = false

    tcp_options {
      min = 5432
      max = 5432
    }
  }

  lifecycle {
    prevent_destroy = true

    ignore_changes = [
      defined_tags
    ]
  }
}
