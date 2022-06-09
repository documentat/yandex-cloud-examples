# Infrastructure for the Yandex Cloud Managed Service for Redis non sharded cluster and Virtual Machine
#
# RU: https://cloud.yandex.ru/docs/managed-redis/tutorials/redis-as-php-sessions-storage
# EN: https://cloud.yandex.com/en/docs/managed-redis/tutorials/redis-as-php-sessions-storage
#
# Set the configuration of the Managed Service for Redis cluster and Virtual Machine


resource "yandex_vpc_network" "redis-and-vm-network" {
  name        = "redis-and-vm-network"
  description = "Network for the Managed Service for Redis cluster and VM."
}

# Subnet in ru-central1-a availability zone
resource "yandex_vpc_subnet" "subnet-a" {
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.redis-and-vm-network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

# Security group for the Managed Service for Redis cluster and VM
resource "yandex_vpc_default_security_group" "redis-and-vm-security-group" {
  network_id = yandex_vpc_network.redis-and-vm-network.id

  ingress {
    protocol       = "TCP"
    description    = "Allow direct connections to master without SSL"
    port           = 6379
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Required for clusters created with TLS
  # ingress {
  #   protocol       = "TCP"
  #   description    = "Allow direct connections to master with SSL"
  #   port           = 6380
  #   v4_cidr_blocks = ["0.0.0.0/0"]
  # }

  ingress {
    protocol       = "TCP"
    description    = "Allow connections to Redis Sentinel"
    port           = 26379
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow SSH connections for VM"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    description    = "Allow outgoing connections to any required resource"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Managed Service for Redis cluster
resource "yandex_mdb_redis_cluster" "redis-cluster" {
  name               = "redis-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.redis-and-vm-network.id
  security_group_ids = [yandex_vpc_default_security_group.redis-and-vm-security-group.id]

  config {
    password = ""    # Set the password
    version  = "6.2" # Version of the Redis
  }

  resources {
    resource_preset_id = "hm2.nano"
    disk_type_id       = "network-ssd"
    disk_size          = 16 # GB
  }

  host {
    zone      = "ru-central1-a"
    subnet_id = yandex_vpc_subnet.subnet-a.id
  }
}

# Compute Virtual Machine
resource "yandex_compute_instance" "intermediate-vm" {

  name        = "intermediate-vm"
  platform_id = "standard-v3" # Intel Ice Lake

  resources {
    cores  = 2
    memory = 2 # GB
  }

  boot_disk {
    initialize_params {
      image_id = "" # Set a public image ID from https://cloud.yandex.com/en/docs/compute/operations/images-with-pre-installed-software/get-list
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet-a.id
    nat                = true # Required for connection from the Internet
    security_group_ids = [yandex_vpc_default_security_group.redis-and-vm-security-group.id]
  }

  metadata = {
    ssh-keys = "<username>:${file("path for SSH public key")}" # Set username and path for SSH public key. If an Ubuntu image is used, the username will be "ubuntu".
  }
}
