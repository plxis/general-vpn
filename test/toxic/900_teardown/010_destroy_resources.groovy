// Destroy existing Terraform stack
// Execute shipyard to destroy any existing resources
assert 0 == memory.shipyard("undeploy", memory.environment)
