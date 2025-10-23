# ----------------------------
# VPC и подсети
# ----------------------------
resource "yandex_vpc_network" "this" {
  name = "network-1"
}

resource "yandex_vpc_subnet" "public" {
  name           = "public"
  zone           = var.zone
  network_id     = yandex_vpc_network.this.id
  v4_cidr_blocks = [var.public_cidr]
}

# Маршрутная таблица для private добавим позже; привяжем её к этой подсети ниже
resource "yandex_vpc_subnet" "private" {
  name           = "private"
  zone           = var.zone
  network_id     = yandex_vpc_network.this.id
  v4_cidr_blocks = [var.private_cidr]
  # route_table_id = будет добавлен после создания таблицы
  route_table_id = yandex_vpc_route_table.private_via_nat.id
}

# ----------------------------
# Security Group: SSH + ICMP
# ----------------------------
resource "yandex_vpc_security_group" "allow_ssh_icmp" {
  name       = "allow-ssh-icmp"
  network_id = yandex_vpc_network.this.id

  ingress {
    protocol       = "TCP"
    description    = "SSH"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "ICMP"
    description    = "ICMP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    description    = "all egress"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ----------------------------
# NAT-инстанс (bastion)
# ----------------------------
resource "yandex_compute_instance" "nat" {
  name        = "nat-instance"
  hostname    = "nat-instance"
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
      image_id = var.image_id_nat
      size     = 10
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.public.id
    nat        = true
    ip_address = var.nat_internal_ip
    security_group_ids = [yandex_vpc_security_group.allow_ssh_icmp.id]
  }

 metadata = {
  user-data = templatefile("${path.module}/meta_web.yml", {
    vm_user        = var.vm_user
    ssh_public_key = var.ssh_public_key
  })
}
}

# ----------------------------
# Route table: private -> NAT instance
# ----------------------------
resource "yandex_vpc_route_table" "private_via_nat" {
  network_id = yandex_vpc_network.this.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = var.nat_internal_ip
  }
}

# Привязываем таблицу к private-подсети
 

