resource "oci_core_instance" "ansible" {
  for_each = local.compute_instances

  compartment_id      = local.compartment_id
  availability_domain = local.availability_domain
  fault_domain        = each.value.fault_domain

  display_name = each.key
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

    display_name           = each.key
    hostname_label         = each.key
    private_ip             = each.value.private_ip
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
