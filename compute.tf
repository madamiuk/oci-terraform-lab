resource "oci_core_instance" "oci_ansible01" {
  compartment_id      = local.compartment_id
  availability_domain = local.availability_domain
  fault_domain        = "FAULT-DOMAIN-2"

  display_name = "oci-ansible01"
  shape        = local.compute_shape

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  source_details {
    source_type = "image"
    source_id   = local.compute_image_id
  }

  create_vnic_details {
    subnet_id = oci_core_subnet.ansible_public.id

    display_name           = "oci-ansible01"
    hostname_label         = "oci-ansible01"
    private_ip             = "10.10.1.37"
    assign_public_ip       = true
    skip_source_dest_check = false
  }

  metadata = {
    ssh_authorized_keys = trimspace(file(local.ssh_public_key_file))
  }

  lifecycle {
    prevent_destroy = true

    ignore_changes = [
      defined_tags
    ]
  }
}

resource "oci_core_instance" "oci_ansible02" {
  compartment_id      = local.compartment_id
  availability_domain = local.availability_domain
  fault_domain        = "FAULT-DOMAIN-1"

  display_name = "oci-ansible02"
  shape        = local.compute_shape

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  source_details {
    source_type = "image"
    source_id   = local.compute_image_id
  }

  create_vnic_details {
    subnet_id = oci_core_subnet.ansible_public.id

    display_name           = "oci-ansible02"
    hostname_label         = "oci-ansible02"
    private_ip             = "10.10.1.176"
    assign_public_ip       = true
    skip_source_dest_check = false
  }

  metadata = {
    ssh_authorized_keys = trimspace(file(local.ssh_public_key_file))
  }

  lifecycle {
    prevent_destroy = true

    ignore_changes = [
      defined_tags
    ]
  }
}

resource "oci_core_instance" "oci_ansible03" {
  compartment_id      = local.compartment_id
  availability_domain = local.availability_domain
  fault_domain        = "FAULT-DOMAIN-3"

  display_name = "oci-ansible03"
  shape        = local.compute_shape

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  source_details {
    source_type = "image"
    source_id   = local.compute_image_id
  }

  create_vnic_details {
    subnet_id = oci_core_subnet.ansible_public.id

    display_name           = "oci-ansible03"
    hostname_label         = "oci-ansible03"
    private_ip             = "10.10.1.26"
    assign_public_ip       = true
    skip_source_dest_check = false
  }

  metadata = {
    ssh_authorized_keys = trimspace(file(local.ssh_public_key_file))
  }

  lifecycle {
    prevent_destroy = true

    ignore_changes = [
      defined_tags
    ]
  }
}
