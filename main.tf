locals {
  rules_redirect_yaml = yamldecode(var.config)
  rules_redirect      = { for each in local.rules_redirect_yaml : each.name => each }
}

resource "cloudflare_list" "redirect_list" {
  for_each = local.rules_redirect

  account_id = var.cloudflare_account_id

  name        = each.value.name
  description = lookup(each.value, "description", "")
  kind        = "redirect"

  dynamic "item" {
    for_each = each.value.items

    content {
      comment = item.value.name

      value {
        redirect {
          source_url = item.value.source
          target_url = item.value.target

          status_code = lookup(item.value, "status_code", 301)

          include_subdomains    = can(item.value.parameters) && lookup(item.value.parameters, "include_subdomains", false) ? "enabled" : "disabled"
          subpath_matching      = can(item.value.parameters) && lookup(item.value.parameters, "subpath_matching", false) ? "enabled" : "disabled"
          preserve_path_suffix  = can(item.value.parameters) && lookup(item.value.parameters, "preserve_path_suffix", false) ? "enabled" : "disabled"
          preserve_query_string = can(item.value.parameters) && lookup(item.value.parameters, "preserve_query_string", false) ? "enabled" : "disabled"
        }
      }
    }
  }
}

resource "cloudflare_ruleset" "redirect_rule" {
  account_id = var.cloudflare_account_id

  kind  = "root"
  phase = "http_request_redirect"
  name  = "Redirect Rules"

  dynamic "rules" {
    for_each = local.rules_redirect

    content {
      enabled = lookup(rules.value, "enabled", true)
      action  = "redirect"

      description = "Apply redirects from ${rules.value.name}"
      expression  = "http.request.full_uri in ${"$"}${rules.value.name}"

      action_parameters {
        from_list {
          name = rules.value.name
          key  = "http.request.full_uri"
        }
      }
    }
  }
}
