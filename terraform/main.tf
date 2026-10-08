check "workspace_matches_environment" {
  assert {
    condition     = terraform.workspace == var.environment
    error_message = "El workspace y el environment deben coincidir."
  }
}