locals {
  nodes = {
    master = {
      name   = "k8s-master"
      memory = var.memory_master
    }
    worker1 = {
      name   = "k8s-worker1"
      memory = var.memory_worker
    }
    worker2 = {
      name   = "k8s-worker2"
      memory = var.memory_worker
    }
  }
}

resource "proxmox_vm_qemu" "k8s" {
  for_each = local.nodes

  name        = each.value.name
  memory      = each.value.memory
  target_node = var.node_name
  clone       = var.template
  full_clone  = true
  os_type     = "cloud-init"
  agent       = 1

  cpu {
    cores   = var.cores
    sockets = 1
    type    = "host"
  }

  scsihw   = "virtio-scsi-pci"
  bootdisk = "scsi0"

  disk {
    slot     = "scsi0"
    size     = var.disk_size
    type     = "disk"
    storage  = "local-lvm"
    iothread = true
  }

  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = "local-lvm"
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = var.bridge
  }
  balloon    = 0
  ciuser     = var.ci_user
  cipassword = var.ci_password
  sshkeys    = file("~/.ssh/id_ed25519.pub")
  ipconfig0  = "ip=${lookup(var.node_ips, each.key)},gw=${var.gateway}"
  nameserver = var.dns
}
