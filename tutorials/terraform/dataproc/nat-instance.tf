# Infrastructure for Yandex Cloud Managed Service for Data Proc cluster and NAT instance Virtual Machine
#
# RU: https://cloud.yandex.ru/docs/data-proc/tutorials/configure-network
# EN: https://cloud.yandex.com/en/docs/data-proc/tutorials/configure-network
#
# Set the Set the configuration of Managed Service for Data Proc cluster and NAT instance Virtual Machine

# Network
resource "yandex_vpc_network" "dataproc-net" {
  name        = "dataproc-net"
  description = "Network for common resources shared with Data Proc cluster"
}

# Security group for Managed Service for Data Proc cluster

resource "yandex_vpc_default_security_group" "dataproc-security-group" {
  network_id = yandex_vpc_network.dataproc-net.id

  # Allow service traffic
  ingress {
    protocol          = "TCP"
    description       = "Allow service traffic"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }

  # Allow service traffic
  egress {
    protocol          = "TCP"
    description       = "Allow service traffic"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }

  # Allow HTTPS traffic
  ingress {
    protocol       = "TCP"
    description    = "Allow HTTPS connections"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "TCP"
    description    = "Allow HTTPS connections"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Subnet for Data Proc clusters
resource "yandex_vpc_subnet" "dataproc-subnet" {
  name           = "dataproc-net"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.dataproc-net.id
  v4_cidr_blocks = ["192.168.1.0/24"]
}

# Subnet for NAT instance VM
resource "yandex_vpc_subnet" "dataproc-nat-net" {
  name           = "dataproc-nat-net"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.dataproc-net.id
  v4_cidr_blocks = ["192.168.100.0/24"]
}

# NAT instance Virtual Machine
resource "yandex_compute_instance" "nat-instance-vm" {

  name        = "nat-instance-vm"
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
    ssh-keys = "<username>:${file("path for SSH public key")}" # Set username and path for SSH public key
  }
}

# Managed Service for Data Proc cluster

resource "yandex_dataproc_cluster" "dataproc-cluster" {
  bucket             = "bucket-dataproc"
  name               = "dataproc-cluster"
  service_account_id = "dataproc-sa.id"
  zone_id            = "ru-central1-a"
  security_group_ids = ["yandex_vpc_default_security_group.dataproc-security-group.id"]

  cluster_config {
    version_id = "2.0"

    hadoop {
      services = ["MAPREDUCE", "SPARK", "YARN", "HDFS", "TEZ"]
      ssh_public_keys = [
        file("path for SSH public key") # Set the path for SSH public key
      ]
    }

    subcluster_spec {
      name = "dataproc-cluster-sub1"
      role = "MASTERNODE"
      resources {
        resource_preset_id = "s2.micro"
        disk_type_id       = "network-ssd"
        disk_size          = 128
      }
      subnet_id   = "dataproc-subnet.id"
      hosts_count = 1
    }

    subcluster_spec {
      name = "dataproc-cluster-sub2"
      role = "DATANODE"
      resources {
        resource_preset_id = "s2.small"
        disk_type_id       = "network-hdd"
        disk_size          = 128
      }
      subnet_id   = "dataproc-subnet.id"
      hosts_count = 1
    }
  }
}