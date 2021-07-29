resource "google_compute_instance_from_template" "linux_static_build_agent" {

    for_each = var.static_agents.linux

    name = each.key

    source_instance_template = google_compute_instance_template.linux_agent_template[each.value.template].id
}

resource "google_compute_instance_from_template" "windows_static_build_agent" {

    for_each = var.static_agents.windows

    name = each.key

    source_instance_template = google_compute_instance_template.windows_agent_template[each.value.template].id
}
