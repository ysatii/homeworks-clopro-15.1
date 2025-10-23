# Задание 1. Yandex Cloud 

**Что нужно сделать**

1. Создать пустую VPC. Выбрать зону.
2. Публичная подсеть.

 - Создать в VPC subnet с названием public, сетью 192.168.10.0/24.
 - Создать в этой подсети NAT-инстанс, присвоив ему адрес 192.168.10.254. В качестве image_id использовать fd80mrhj8fl2oe87o4e1.
 - Создать в этой публичной подсети виртуалку с публичным IP, подключиться к ней и убедиться, что есть доступ к интернету.
3. Приватная подсеть.
 - Создать в VPC subnet с названием private, сетью 192.168.20.0/24.
 - Создать route table. Добавить статический маршрут, направляющий весь исходящий трафик private сети в NAT-инстанс.
 - Создать в этой приватной подсети виртуалку с внутренним IP, подключиться к ней через виртуалку, созданную ранее, и убедиться, что есть доступ к интернету.

Resource Terraform для Yandex Cloud:

- [VPC subnet](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_subnet).
- [Route table](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_route_table).
- [Compute Instance](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/compute_instance).

---

cd terraform
terraform plan
terraform apply -auto-approve

ssh lamer@$(terraform output -raw nat_public_ip)

### hostname
# → nat-instance

ssh -J lamer@$(terraform output -raw nat_public_ip) lamer@$(terraform output -raw private_vm_internal_ip)
### hostname
# → private-vm

# Ответ 1
Для решения данной задчи нам понядобиться следущая файловая структура 
```
── main.tf
├── meta_web.yml
├── outputs.tf
├── personal.auto.tfvars
├── private_vm.tf
├── providers.tf
├── terraform.tfstate
├── terraform.tfstate.backup
├── variables.tf
└── versions.tf
```

1. main.tf - содержит блок 
создание сети и под сети 
```
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
```

Security Group: SSH + ICMP
```
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
```

NAT-инстанс (bastion)
```
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
    user-data = "${file("./meta_web.yml")}"
  }
}
```

таблица маршрутизации
```
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
```
------

2. meta_web.yml содержит метаинформацию для создания машин
```
#cloud-config
users:
  - name: lamer
    groups: sudo
    shell: /bin/bash
    sudo: 'ALL=(ALL) NOPASSWD:ALL'
    ssh_authorized_keys:
      - ${var.ssh_public_key}
```

3. outputs.tf - выводит переменные в которых содержаться ип адреса виртуальных машин
```
output "nat_public_ip" {
  value       = yandex_compute_instance.nat.network_interface[0].nat_ip_address
  description = "NAT instance public IP"
}

 

output "private_vm_internal_ip" {
  value       = yandex_compute_instance.private_vm.network_interface[0].ip_address
  description = "Private VM internal IP"
}

output "nat_internal_ip" {
  value       = yandex_compute_instance.nat.network_interface[0].ip_address
  description = "NAT instance internal IP (should be 192.168.10.254)"
}
```
------

4.  private_vm.tf  создает машину внутри приватной сети 
```
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
    user-data = "${file("./meta_web.yml")}"
  }
}
```
имя  машины -  **private-vm**
метаданные из файла   **meta_web.yml**
колличество ядер -**2** 
память - **2 ГБ**
использование ядра - **50 %** 
network_interface, nat = false - **нет внешнего ип**
-----




