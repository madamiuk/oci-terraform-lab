output "availability_domains" {
  description = "OCI availability domains available in the tenancy"

  value = data.oci_identity_availability_domains.ads.availability_domains[*].name
}

output "vcn_id" {
  description = "OCID of the Ansible lab VCN"

  value = oci_core_vcn.ansible_lab.id
}

output "vcn_cidr" {
  description = "CIDR block of the Ansible lab VCN"

  value = oci_core_vcn.ansible_lab.cidr_blocks
}

output "subnet_id" {
  description = "OCID of the public subnet"

  value = oci_core_subnet.ansible_public.id
}

output "subnet_cidr" {
  description = "CIDR block of the public subnet"

  value = oci_core_subnet.ansible_public.cidr_block
}

output "instance_ids" {
  description = "OCIDs of OCI compute instances"

  value = {
    for name, instance in oci_core_instance.ansible :
    name => instance.id
  }
}

output "instance_private_ips" {
  description = "Private IP addresses of OCI compute instances"

  value = {
    for name, instance in oci_core_instance.ansible :
    name => instance.private_ip
  }
}

output "instance_public_ips" {
  description = "Public IP addresses of OCI compute instances"

  value = {
    for name, instance in oci_core_instance.ansible :
    name => instance.public_ip
  }
}

output "ansible_hosts" {
  description = "OCI compute information prepared for Ansible inventory generation"

  value = {
    for name, instance in oci_core_instance.ansible :
    name => {
      ansible_host = instance.public_ip
      private_ip   = instance.private_ip
      ansible_user = "opc"
      groups       = local.compute_instances[name].ansible_groups
    }
  }
}
