output "bound" {
  description = "The hostnames bound on this apply."
  value       = keys(local.bound)
}
