# Vault Persistent Configuration (Raft Storage Backend)
# This configuration enables persistent storage using HashiCorp Raft
# For development environment in Docker container

storage "raft" {
  path = "/vault/data"
  node_id = "vault-dev-node1"
}

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = 1
}

api_addr = "http://vault-dev:8200"
cluster_addr = "http://vault-dev:8201"
ui = true
disable_mlock = true  # Required for Docker containers
