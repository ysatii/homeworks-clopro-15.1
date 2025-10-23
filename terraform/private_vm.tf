# ----------------------------
# Private VM (только внутр. адрес)
# ----------------------------
resource "yandex_compute_instance" "private_vm" {
  name        = "private-vm"
  hostname    = "private-vm"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores  = 2
    memory = 2
    core_fraction = 50
  }

  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id_ubuntu
      size     = 10
    }
  }

  network_interface {
    subnet_id           = yandex_vpc_subnet.private.id
    nat                 = false
    security_group_ids  = [yandex_vpc_security_group.allow_ssh_icmp.id]
  }

  metadata = {
  user-data = templatefile("${path.module}/meta_web.yml", {
    vm_user        = var.vm_user
    ssh_public_key = var.ssh_public_key
  })
}
}
