output "tags" {
  description = "Merged tag map: standard set plus var.extra_tags (extra wins on key collision)."
  value       = merge(local.standard, var.extra_tags)
}
