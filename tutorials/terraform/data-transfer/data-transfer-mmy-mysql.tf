locals {
  folder_id      = "" # Set your cloud folder ID
  mdb-cluster-id = "" # Set the Managed Service for MySQL cluster ID
  user-source    = "" # Set the source username 
  user-target    = "" # Set the target username
  db-source      = "" # Set the source database name
  db-target      = "" # Set the target database name
  pwd-source     = "" # Set the source password
  pwd-target     = "" # Set the target password
  host-target    = "" # Set the target master host IP address or FQDN
  port-target    = "" # Set the target port number that Data Transfer will use for connections
}

resource "yandex_datatransfer_endpoint" "managed-mysql-source" {
  name = "managed-mysql-source"
  settings {
    mysql_source {
      connection {
        mdb_cluster_id = local.mdb-cluster-id
      }
      database = local.db-source
      user     = local.user-source
      password {
        raw = local.pwd-source
      }
    }
  }
}

resource "yandex_datatransfer_endpoint" "mysql-target" {
  folder_id = local.folder_id
  name      = "mysql-target"
  settings {
    mysql_target {
      connection {
        on_premise {
          hosts = [local.host-target]
          port  = local.port-target
        }
      }
      database = local.db-target
      user     = local.user-target
      password {
        raw = local.pwd-target
      }
    }
  }
}

resource "yandex_datatransfer_transfer" "mysql-transfer" {
  folder_id = local.folder_id
  name      = "mysql"
  source_id = yandex_datatransfer_endpoint.managed-mysql-source.id
  target_id = yandex_datatransfer_endpoint.mysql-target.id
  type      = "SNAPSHOT_AND_INCREMENT"
}