variable "node_name" {
  type    = string
  default = "proxmox"
}

variable "template" {
  type    = string
  default = "vm-9000"
}

variable "cores" {
  type    = number
  default = 2
}

variable "memory_master" {
  type    = number
  default = 4096
}

variable "memory_worker" {
  type    = number
  default = 2048
}

variable "disk_size" {
  type    = string
  default = "15G"
}

variable "scsihw" {
  type    = string
  default = "virtio-scsi-pci"
}

variable "bootdisk" {
  type    = string
  default = "scsi0"
}

variable "bridge" {
  type    = string
  default = "vmbr0"
}

variable "ci_user" {
  type    = string
  default = "ubuntu"
}

variable "ci_password" {
  type      = string
  sensitive = true
  default   = "1234"
}

variable "node_ips" {
  type = map(string)
  default = {
    master  = "192.168.88.210/24"
    worker1 = "192.168.88.211/24"
    worker2 = "192.168.88.212/24"
  }
}

variable "gateway" {
  type    = string
  default = "192.168.88.1"
}

variable "dns" {
  type    = string
  default = "8.8.8.8"
}
