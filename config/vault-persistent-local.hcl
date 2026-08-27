storage "raft" {
  path = "/workspaces/diamonds_dev_env/.devcontainer/data/vault-data"
  node_id = "vault-dev-local"
}

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = 1
}

api_addr = "http://127.0.0.1:8200"
cluster_addr = "http://127.0.0.1:8201"
ui = true
disable_mlock = true
