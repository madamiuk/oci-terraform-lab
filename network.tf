resource "oci_core_vcn" "ansible_lab" {
  compartment_id = local.compartment_id

  cidr_blocks = [
    local.vcn_cidr
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
  compartment_id = local.compartment_id

  vcn_id     = oci_core_vcn.ansible_lab.id
  cidr_block = local.public_subnet_cidr

  display_name = "ansible-public-subnet"
  dns_label    = "ansiblepublicsu"

  route_table_id = oci_core_route_table.ansible_lab_default.id

  security_list_ids = [
    oci_core_security_list.ansible_lab_default.id
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
  compartment_id = local.compartment_id
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
  compartment_id = local.compartment_id
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
  compartment_id = local.compartment_id
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
    source      = local.vcn_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false

    icmp_options {
      type = 3
    }
  }

  ingress_security_rules {
    description = "Allow ICMP echo within Ansible lab VCN"
    protocol    = "1"
    source      = local.public_subnet_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false

    icmp_options {
      type = 8
    }
  }

  ingress_security_rules {
    description = "Allow NRPE from Nagios server"
    protocol    = "6"
    source      = "${local.compute_instances["oci-ansible02"].private_ip}/32"
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
    source      = "${local.compute_instances["oci-ansible02"].private_ip}/32"
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
    source      = "${local.compute_instances["oci-ansible01"].private_ip}/32"
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
    source      = "${local.compute_instances["oci-ansible02"].private_ip}/32"
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
