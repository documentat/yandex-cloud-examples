# Infrastructure for Yandex Cloud Managed Service for SQL Server
#
# RU: https://cloud.yandex.ru/docs/managed-sqlserver/tutorials/data-migration
# EN: https://cloud.yandex.com/en/docs/managed-sqlserver/tutorials/data-migration
#
# Set the configuration of Managed Service for SQL Server:
#      * DBMS version and edition
#      * database name
#      * name and password of the database owner user

# Network
resource "yandex_vpc_network" "network" {
  name        = "network"
  description = "Network for Managed Service for SQL Server."
}

# Subnet in ru-central1-a availability zone
resource "yandex_vpc_subnet" "subnet-a" {
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

# Security group for Managed Service for SQL Server
resource "yandex_vpc_default_security_group" "security-group" {
  network_id = yandex_vpc_network.network.id

  # Allow connections to SQL Server cluster from the Internet
  ingress {
    protocol       = "TCP"
    description    = "Allow connections to SQL Server from the Internet"
    port           = 1433
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

# Managed Service for SQL Server
resource "yandex_mdb_sqlserver_cluster" "sqlserver-cluster" {
  name               = "sqlserver-cluster"
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.network.id
  version            = "" # Set DBMS version and edition
  security_group_ids = [yandex_vpc_default_security_group.security-group.id]

  resources {
    resource_preset_id = "s2.small"
    disk_type_id       = "network-hdd"
    disk_size          = 10 # GB
  }

  host {
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.subnet-a.id
    assign_public_ip = true
  }

  database {
    name = "" # Set the database name
  }

  user {
    name     = "" # Set the name of the database owner user
    password = "" # Set the password of the database owner user

    permission {
      database_name = "" # Database name
      roles         = ["OWNER"]
    }
  }
}
