# Infrastructure for the Yandex Cloud Managed Service for ClickHouse cluster with hybrid storage
#
# RU: https://cloud.yandex.ru/docs/managed-clickhouse/tutorials/hybrid-storage
# EN: https://cloud.yandex.com/en/docs/managed-clickhouse/tutorials/hybrid-storage
#
# Set the user name and password for the Managed Service for ClickHouse cluster


resource "yandex_vpc_network" "clickhouse_hybrid_storage_network" {
  name        = "clickhouse-hybrid-storage-network"
  description = "Network for the Managed Service for ClickHouse cluster with hybrid storage."
}

# Subnet in ru-central1-a availability zone
resource "yandex_vpc_subnet" "subnet-a" {
  name           = "clickhouse-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.clickhouse_hybrid_storage_network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

# Security group for the Managed Service for ClickHouse cluster
resource "yandex_vpc_default_security_group" "clickhouse-security-group" {
  network_id = yandex_vpc_network.clickhouse_hybrid_storage_network.id

  ingress {
    protocol       = "TCP"
    description    = "Allow incoming connections to cluster from Internet"
    port           = 9440
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

# Managed Service for ClickHouse cluster with enabled hybrid storage
resource "yandex_mdb_clickhouse_cluster" "clickhouse-cluster" {
  name               = "clickhouse-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.clickhouse_hybrid_storage_network.id
  security_group_ids = [yandex_vpc_default_security_group.clickhouse-security-group.id]

  clickhouse {
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = 32 # GB
    }
  }

  host {
    type             = "CLICKHOUSE"
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.subnet-a.id
    assign_public_ip = true # Required for connection from Internet
  }

  database {
    name = "tutorial"
  }

  user {
    name     = "" # Set username
    password = "" # Set user password
    permission {
      database_name = "tutorial"
    }
  }

  # Enable hybrid storage
  cloud_storage {
    enabled = true
  }
}
