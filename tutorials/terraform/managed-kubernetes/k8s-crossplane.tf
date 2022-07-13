# Infrastructure for Yandex Cloud Managed Service for Kubernetes cluster and routing VM.
#
# Set the configuration of the Managed Service for Kubernetes cluster.

locals {
  folder_id             = ""                     # Set your cloud folder ID.
  k8s_version           = "1.21"                 # Set the version of Kubernetes for the master node and node group.
  zone_a_v4_cidr_blocks = "10.1.0.0/16"          # Set the CIDR block for subnet.
  sa_name               = ""                     # Set the service account name.
  image_id              = "fd8qs44945ddtla09hnr" # Set the Linux VM image ID.
  vm_username           = ""                     # Set the username to connect to the routing VM via SSH
  vm_ssh_key_path       = "~/.ssh/key.pub"       # Set the path to the public SSH public key for the routing VM
}

resource "yandex_vpc_network" "k8s-network" {
  description = "Network for the Managed Service for Kubernetes cluster"
  name        = "k8s-network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in ru-central1-a availability zone"
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.k8s-network.id
  v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
}

resource "yandex_vpc_security_group" "k8s-main-sg" {
  description = "Security group for the Managed Service for Kubernetes cluster"
  name        = "k8s-main-sg"
  network_id  = yandex_vpc_network.k8s-network.id
}

resource "yandex_vpc_security_group_rule" "loadbalancer" {
  description            = "The rule allows availability checks from the load balancer's range of addresses"
  direction              = "ingress"
  security_group_binding = yandex_vpc_security_group.k8s-main-sg.id
  protocol               = "TCP"
  predefined_target      = "loadbalancer_healthchecks" # The load balancer's address range.
  from_port              = 0
  to_port                = 65535
}

resource "yandex_vpc_security_group_rule" "node-interaction" {
  description            = "The rule allows the master-node and node-node interaction within the security group"
  direction              = "ingress"
  security_group_binding = yandex_vpc_security_group.k8s-main-sg.id
  protocol               = "ANY"
  predefined_target      = "self_security_group"
  from_port              = 0
  to_port                = 65535
}

resource "yandex_vpc_security_group_rule" "pod-service-interaction" {
  description            = "The rule allows the pod-pod and service-service interaction"
  direction              = "ingress"
  security_group_binding = yandex_vpc_security_group.k8s-main-sg.id
  protocol               = "ANY"
  v4_cidr_blocks         = [local.zone_a_v4_cidr_blocks]
  from_port              = 0
  to_port                = 65535
}

resource "yandex_vpc_security_group_rule" "ICMP-debug" {
  description            = "The rule allows receipt of debugging ICMP packets from internal subnets"
  direction              = "ingress"
  security_group_binding = yandex_vpc_security_group.k8s-main-sg.id
  protocol               = "ICMP"
  v4_cidr_blocks         = [local.zone_a_v4_cidr_blocks]
}

resource "yandex_vpc_security_group_rule" "port-6443" {
  description            = "The rule allows connection to Kubernetes API on 6443 port from the Internet"
  direction              = "ingress"
  security_group_binding = yandex_vpc_security_group.k8s-main-sg.id
  protocol               = "TCP"
  v4_cidr_blocks         = ["0.0.0.0/0"]
  port                   = 6443
}

resource "yandex_vpc_security_group_rule" "port-443" {
  description            = "The rule allows connection to Kubernetes API on 443 port from the Internet"
  direction              = "ingress"
  security_group_binding = yandex_vpc_security_group.k8s-main-sg.id
  protocol               = "TCP"
  v4_cidr_blocks         = ["0.0.0.0/0"]
  port                   = 443
}

resource "yandex_vpc_security_group_rule" "outgoing-traffic" {
  description            = "The rule allows all outgoing traffic"
  direction              = "egress"
  security_group_binding = yandex_vpc_security_group.k8s-main-sg.id
  protocol               = "ANY"
  v4_cidr_blocks         = ["0.0.0.0/0"]
  from_port              = 0
  to_port                = 65535
}

resource "yandex_iam_service_account" "k8s-sa" {
  description = "Service account for the Managed Service for Kubernetes cluster and node group"
  name        = local.sa_name
}

# Assign "editor" role to service account.
resource "yandex_resourcemanager_folder_iam_binding" "editor" {
  folder_id = local.folder_id
  role      = "editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  ]
}

# Assign "admin" role to service account.
resource "yandex_resourcemanager_folder_iam_binding" "admin" {
  folder_id = local.folder_id
  role      = "admin"
  members = [
    "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  ]
}

# Assign "container-registry.images.puller" role to service account.
resource "yandex_resourcemanager_folder_iam_binding" "images-puller" {
  folder_id = local.folder_id
  role      = "container-registry.images.puller"
  members = [
    "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  ]
}

resource "yandex_kubernetes_cluster" "k8s-cluster" {
  description = "Managed Service for Kubernetes cluster"
  name        = "k8s-cluster"
  network_id  = yandex_vpc_network.k8s-network.id

  master {
    version = local.k8s_version
    zonal {
      zone      = yandex_vpc_subnet.subnet-a.zone
      subnet_id = yandex_vpc_subnet.subnet-a.id
    }

    public_ip = true

    security_group_ids = [yandex_vpc_security_group.k8s-main-sg.id]
  }
  service_account_id      = yandex_iam_service_account.k8s-sa.id # Cluster service account ID.
  node_service_account_id = yandex_iam_service_account.k8s-sa.id # Node group service account ID.
  depends_on = [
    yandex_resourcemanager_folder_iam_binding.editor,
    yandex_resourcemanager_folder_iam_binding.images-puller
  ]
}

resource "yandex_kubernetes_node_group" "k8s-node-group" {
  description = "Node group for the Managed Service for Kubernetes cluster"
  name        = "k8s-node-group"
  cluster_id  = yandex_kubernetes_cluster.k8s-cluster.id
  version     = local.k8s_version

  scale_policy {
    fixed_scale {
      size = 1 # Number of hosts
    }
  }

  allocation_policy {
    location {
      zone = yandex_vpc_subnet.subnet-a.zone
    }
  }

  instance_template {
    platform_id = "standard-v2" # Intel Cascade Lake

    network_interface {
      nat                = true
      subnet_ids         = [yandex_vpc_subnet.subnet-a.id]
      security_group_ids = [yandex_vpc_security_group.k8s-main-sg.id]
    }

    resources {
      memory = 4 # GB
      cores  = 4 # Number of CPU cores.
    }

    boot_disk {
      type = "network-hdd"
      size = 64 # GB
    }
  }
}

# Traffic routing Virtual Machine
resource "yandex_compute_instance" "routing-vm" {

  name        = "routing-vm"
  platform_id = "standard-v3" # Intel Ice Lake

  resources {
    cores  = 2
    memory = 2 # GB
  }

  boot_disk {
    initialize_params {
      image_id = local.image_id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-a.id
    nat       = true # Required for connection from the Internet
  }

  metadata = {
    ssh-keys = "local.vm_username:${file(local.vm_ssh_key_path)}"
  }
}