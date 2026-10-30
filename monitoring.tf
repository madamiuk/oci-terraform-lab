resource "oci_ons_notification_topic" "ansible_lab_alerts" {
  compartment_id = var.compartment_id
  name           = "ansible-lab-alerts"
  description    = "OCI monitoring alerts for the Ansible lab"
}

resource "oci_ons_subscription" "ansible_lab_email" {
  compartment_id = var.compartment_id
  topic_id       = oci_ons_notification_topic.ansible_lab_alerts.id
  protocol       = "EMAIL"
  endpoint       = var.notification_email
}

locals {
  compute_alarm_definitions = {
    high_cpu = {
      display_suffix   = "high-cpu"
      namespace        = "oci_computeagent"
      metric           = "CpuUtilization"
      interval         = "1m"
      condition        = ".mean() > 80"
      severity         = "WARNING"
      pending_duration = "PT5M"
      body             = "CPU utilization has exceeded 80% for at least 5 minutes."
    }

    high_memory = {
      display_suffix   = "high-memory"
      namespace        = "oci_computeagent"
      metric           = "MemoryUtilization"
      interval         = "1m"
      condition        = ".mean() > 85"
      severity         = "WARNING"
      pending_duration = "PT5M"
      body             = "Memory utilization has exceeded 85% for at least 5 minutes."
    }

    high_load = {
      display_suffix   = "high-load"
      namespace        = "oci_computeagent"
      metric           = "LoadAverage"
      interval         = "1m"
      condition        = ".mean() > 1.5"
      severity         = "WARNING"
      pending_duration = "PT5M"
      body             = "Load average has exceeded 1.5 for at least 5 minutes."
    }
  }

  compute_alarms = merge([
    for alarm_name, alarm in local.compute_alarm_definitions : {
      for host_name, instance in oci_core_instance.ansible :
      "${host_name}:${alarm_name}" => merge(alarm, {
        host_name   = host_name
        instance_id = instance.id
      })
    }
  ]...)
}

moved {
  from = oci_monitoring_alarm.oci_ansible01_high_cpu
  to   = oci_monitoring_alarm.compute["oci-ansible01:high_cpu"]
}

resource "oci_monitoring_alarm" "compute" {
  for_each = local.compute_alarms

  compartment_id        = var.compartment_id
  metric_compartment_id = var.compartment_id

  display_name = "${each.value.host_name}-${each.value.display_suffix}"
  namespace    = each.value.namespace

  query = format(
    "%s[%s]{resourceId = \"%s\"}%s",
    each.value.metric,
    each.value.interval,
    each.value.instance_id,
    each.value.condition
  )

  severity         = each.value.severity
  pending_duration = each.value.pending_duration
  is_enabled       = true

  destinations = [
    oci_ons_notification_topic.ansible_lab_alerts.id
  ]

  message_format = "ONS_OPTIMIZED"

  body = "${each.value.host_name}: ${each.value.body}"
}

locals {
  health_alarm_definitions = {
    instance_unreachable = {
      display_suffix   = "instance-unreachable"
      namespace        = "oci_compute_instance_health"
      metric           = "instance_accessibility_status"
      interval         = "1m"
      condition        = ".max() > 0"
      severity         = "CRITICAL"
      pending_duration = "PT5M"
      body             = "Instance has been unreachable for at least 5 minutes."
    }

    infrastructure_down = {
      display_suffix   = "infrastructure-down"
      namespace        = "oci_compute_infrastructure_health"
      metric           = "instance_status"
      interval         = "1m"
      condition        = ".max() > 0"
      severity         = "CRITICAL"
      pending_duration = "PT5M"
      body             = "OCI infrastructure reports the instance unavailable for at least 5 minutes."
    }
  }

  health_alarms = merge([
    for alarm_name, alarm in local.health_alarm_definitions : {
      for host_name, instance in oci_core_instance.ansible :
      "${host_name}:${alarm_name}" => merge(alarm, {
        host_name   = host_name
        instance_id = instance.id
      })
    }
  ]...)
}

resource "oci_monitoring_alarm" "health" {
  for_each = local.health_alarms

  compartment_id        = var.compartment_id
  metric_compartment_id = var.compartment_id

  display_name = "${each.value.host_name}-${each.value.display_suffix}"
  namespace    = each.value.namespace

  query = format(
    "%s[%s]{resourceId = \"%s\"}%s",
    each.value.metric,
    each.value.interval,
    each.value.instance_id,
    each.value.condition
  )

  severity         = each.value.severity
  pending_duration = each.value.pending_duration
  is_enabled       = true

  destinations = [
    oci_ons_notification_topic.ansible_lab_alerts.id
  ]

  message_format = "ONS_OPTIMIZED"

  body = "${each.value.host_name}: ${each.value.body}"
}

resource "oci_ons_subscription" "ansible_lab_sms" {
  compartment_id = var.compartment_id
  topic_id       = oci_ons_notification_topic.ansible_lab_alerts.id
  protocol       = "SMS"
  endpoint       = var.notification_sms_phone
}
