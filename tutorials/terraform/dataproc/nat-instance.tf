# Infrastructure for Yandex Cloud Managed Service for Data Proc cluster and NAT instance Virtual Machine
#
# RU: https://cloud.yandex.ru/docs/data-proc/tutorials/configure-network
# EN: https://cloud.yandex.com/en/docs/data-proc/tutorials/configure-network
#
# Set the subnets of Managed Service for Data Proc cluster and NAT instance Virtual Machine

# Network
resource "yandex_vpc_network" "common-resources-network" {
  name        = "common-resources-network"
  description = "Network for common resources shared with Data Proc cluster"
}

# Subnet for Data Proc clusters
resource "yandex_vpc_subnet" "dataproc-net" {
  name           = "dataproc-net"
  zone           = "ru-central1-c"
  network_id     = yandex_vpc_network.common-resources-network.id
  v4_cidr_blocks = ["192.168.1.0/24"]
}

# Subnet for NAT instance VM
resource "yandex_vpc_subnet" "dataproc-nat-net" {
  name           = "dataproc-nat-net"
  zone           = "ru-central1-c"
  network_id     = yandex_vpc_network.common-resources-network.id
  v4_cidr_blocks = ["192.168.100.0/24"]
}

# NAT instance Virtual Machine
resource "yandex_compute_instance" "intermediate-vm" {

  name        = "nat-instance"
  platform_id = "standard-v3" # Intel Ice Lake

  resources {
    cores  = 2
    memory = 2 # GB
  }

  boot_disk {
    initialize_params {
      image_id = "fd85vbr6kin3r8ro2e95"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.dataproc-nat-net.id
    nat       = true # Required for connection from the Internet
  }

  metadata = {
    ssh-keys = "<user>:${file("path for SSH public key")}" # Set username and path for SSH public key
  }
}