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

resource "oci_ons_subscription" "ansible_lab_sms" {
  compartment_id = var.compartment_id
  topic_id       = oci_ons_notification_topic.ansible_lab_alerts.id
  protocol       = "SMS"
  endpoint       = var.notification_sms_phone
}


# ---------------------------------------------------------------------------
# Compute monitoring policy
# ---------------------------------------------------------------------------

locals {
  compute_alarm_definitions = {
    high_cpu = {
      display_suffix = "high-cpu"
      namespace      = "oci_computeagent"
      metric         = "CpuUtilization"
      interval       = "1m"
      aggregation    = ".mean()"

      default = {
        threshold        = 80
        severity         = "WARNING"
        pending_duration = "PT5M"
      }

      body = "CPU utilization has exceeded the configured threshold."
    }

    high_memory = {
      display_suffix = "high-memory"
      namespace      = "oci_computeagent"
      metric         = "MemoryUtilization"
      interval       = "1m"
      aggregation    = ".mean()"

      default = {
        threshold        = 85
        severity         = "WARNING"
        pending_duration = "PT5M"
      }

      body = "Memory utilization has exceeded the configured threshold."
    }

    high_load = {
      display_suffix = "high-load"
      namespace      = "oci_computeagent"
      metric         = "LoadAverage"
      interval       = "1m"
      aggregation    = ".mean()"

      default = {
        threshold        = 1.5
        severity         = "WARNING"
        pending_duration = "PT5M"
      }

      body = "Load average has exceeded the configured threshold."
    }
  }

  monitoring_group_overrides = {
    appservers = {
      high_cpu = {
        threshold        = 80
        severity         = "WARNING"
        pending_duration = "PT5M"
      }

      high_memory = {
        threshold        = 85
        severity         = "WARNING"
        pending_duration = "PT5M"
      }

      high_load = {
        threshold        = 1.5
        severity         = "WARNING"
        pending_duration = "PT5M"
      }
    }

    nagios_server = {
      high_cpu = {
        threshold        = 80
        severity         = "WARNING"
        pending_duration = "PT5M"
      }

      high_memory = {
        threshold        = 85
        severity         = "WARNING"
        pending_duration = "PT5M"
      }

      high_load = {
        threshold        = 1.5
        severity         = "WARNING"
        pending_duration = "PT5M"
      }
    }

    oci_database = {
      high_cpu = {
        threshold        = 75
        severity         = "WARNING"
        pending_duration = "PT5M"
      }

      high_memory = {
        threshold        = 80
        severity         = "WARNING"
        pending_duration = "PT5M"
      }

      high_load = {
        threshold        = 1.2
        severity         = "WARNING"
        pending_duration = "PT5M"
      }
    }
  }

  compute_alarms = merge([
    for alarm_name, alarm in local.compute_alarm_definitions : {
      for host_name, instance in oci_core_instance.ansible :
      "${host_name}:${alarm_name}" => merge(
        alarm,
        alarm.default,
        merge(
          concat(
            [{}],
            [
              for group_name in local.compute_instances[host_name].ansible_groups :
              try(
                local.monitoring_group_overrides[group_name][alarm_name],
                {}
              )
            ]
          )...
        ),
        {
          host_name   = host_name
          instance_id = instance.id
        }
      )
    }
  ]...)
}


resource "oci_monitoring_alarm" "compute" {
  for_each = local.compute_alarms

  compartment_id        = var.compartment_id
  metric_compartment_id = var.compartment_id

  display_name = "${each.value.host_name}-${each.value.display_suffix}"
  namespace    = each.value.namespace

  query = format(
    "%s[%s]{resourceId = \"%s\"}%s > %v",
    each.value.metric,
    each.value.interval,
    each.value.instance_id,
    each.value.aggregation,
    each.value.threshold
  )

  severity         = each.value.severity
  pending_duration = each.value.pending_duration
  is_enabled       = true

  destinations = [
    oci_ons_notification_topic.ansible_lab_alerts.id
  ]

  message_format = "ONS_OPTIMIZED"

  body = format(
    "%s: %s Threshold: %v.",
    each.value.host_name,
    each.value.body,
    each.value.threshold
  )
}


# Keep Terraform state continuity after migration from the original
# single oci-ansible01 CPU alarm.
moved {
  from = oci_monitoring_alarm.oci_ansible01_high_cpu
  to   = oci_monitoring_alarm.compute["oci-ansible01:high_cpu"]
}


# ---------------------------------------------------------------------------
# Instance and infrastructure health monitoring
# ---------------------------------------------------------------------------

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
      "${host_name}:${alarm_name}" => merge(
        alarm,
        {
          host_name   = host_name
          instance_id = instance.id
        }
      )
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
