terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc04"
    }
  }
}

provider "proxmox" {
  pm_api_url          = "https://192.168.88.200:8006/api2/json"
  pm_api_token_id     = "martins@pam!terraform"
  pm_api_token_secret = "44153ec2-1792-4158-941c-db0be1a04983"
  pm_tls_insecure     = true
}
