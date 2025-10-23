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
### имя  машины -  **private-vm**  
### метаданные из файла   **meta_web.yml**  
### колличество ядер -**2**   
### память - **2 ГБ**  
### использование ядра - **50 %**  
### network_interface, nat = false - **нет внешнего ип**  
-----

5. providers.tf  - содержит описание облачного провайдера 
```
provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.zone
}
```
-----

6. variables.tf - содержит описание перменных используемых в решении 
```
variable "yc_token"     { 
    type = string
    sensitive = true 
}

variable "yc_cloud_id"  {
    type = string 
    default         = "b1ggavufohr5p1bfj10e"
    description = "https://cloud.yandex.ru/docs/resource-manager/operations/cloud/get-id"
}

variable "yc_folder_id" {
    default         = "b1g0hcgpsog92sjluneq"
    description = "https://cloud.yandex.ru/docs/resource-manager/operations/folder/get-id" 
     }
variable "zone"         {
    type        = string
    default     = "ru-central1-a"
    description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}

# Сеть
variable "public_cidr"  {
    type = string
    default = "192.168.10.0/24" 
}

variable "private_cidr" {
    type = string
    default = "192.168.20.0/24" 
}

# NAT-инстанс внутренний статический IP (в public-подсети)
variable "nat_internal_ip" {
    type = string 
    default = "192.168.10.254"
}

# Пользователь и SSH ключ
variable "vm_user"      {
    type = string
    default = "lamer" 
}
variable "ssh_public_key" {
  type        = string
  default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGJ/8nl4RWFm+0oXUDpUSjuOP3AHCl2E/af1CpzwhtO6 lamer@lamer-VirtualBox"
  description = "содержимое ~/.ssh/id_ed25519.pub"
}

# Образы
variable "image_id_ubuntu" {
  type        = string
  description = "fd86rorl7r6l2nq3ate6" 
  default     = "fd86rorl7r6l2nq3ate6" 
}
variable "image_id_nat" {
  type        = string
  description = "ID образа NAT-инстанса из задания"
  default     = "fd80mrhj8fl2oe87o4e1"
}
```
-----

7.  versions.tf - описание версии провайдера yandex-cloud/yandex  
```
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.129" # актуальная на момент написания ветка
    }
  }
}
```


## Произвдем запуск 
```
cd terraform
terraform init 
terraform plan
terraform apply -auto-approve
```

![Рисунок 1](https://github.com/ysatii/homeworks-clopro-15.1/blob/main/img/img1.jpg)
ип адреса машины с внешним адресом  
nat_internal_ip = "192.168.10.254"
nat_public_ip = "84.252.129.23"

ип адреса машины в приватной сети  
private_vm_internal_ip = "192.168.20.34"  

## Посмотрим что создалось в облаке 
### виртуальные машины 
![Рисунок 2](https://github.com/ysatii/homeworks-clopro-15.1/blob/main/img/img2.jpg)  
![Рисунок 3](https://github.com/ysatii/homeworks-clopro-15.1/blob/main/img/img3.jpg)  
![Рисунок 4](https://github.com/ysatii/homeworks-clopro-15.1/blob/main/img/img4.jpg)  

### Виртуальные  стети
![Рисунок 5](https://github.com/ysatii/homeworks-clopro-15.1/blob/main/img/img5.jpg)
![Рисунок 6](https://github.com/ysatii/homeworks-clopro-15.1/blob/main/img/img6.jpg)

### Таблицы маршрутизации
![Рисунок 7](https://github.com/ysatii/homeworks-clopro-15.1/blob/main/img/img7.jpg)

### Группы безопастности
![Рисунок 8](https://github.com/ysatii/homeworks-clopro-15.1/blob/main/img/img8.jpg)

### Карта оболачной сети
![Рисунок 9](https://github.com/ysatii/homeworks-clopro-15.1/blob/main/img/img9.jpg)
![Рисунок 10](https://github.com/ysatii/homeworks-clopro-15.1/blob/main/img/img10.jpg)



## Произвдем подключение к машине nat-instance имеющей внешней адрес  
### подлючимся к машине проверим наличие интернета и пропингуем машину из приватной сети
```
ssh lamer@$(terraform output -raw nat_public_ip)
```
![Рисунок 11](https://github.com/ysatii/homeworks-clopro-15.1/blob/main/img/img11.jpg)


 

ssh -J lamer@$(terraform output -raw nat_public_ip) lamer@$(terraform output -raw private_vm_internal_ip)
### hostname
# → private-vm



