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
