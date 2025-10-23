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
