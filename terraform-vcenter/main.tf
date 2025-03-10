/*

Terraform module which create vApp VM ressources on VMWare vSphere.

*/

terraform {
  required_version = ">= 1.8.0"
  required_providers {
    vsphere = {
      source = "hashicorp/vsphere"
      version = "2.10.0"
    }
  }
}

provider "vsphere" {
  vsphere_server              = var.vsphere_endpoint
  user                        = var.vsphere_username
  password                    = var.vsphere_password
  allow_unverified_ssl        = var.vsphere_insecure_connection
}

locals {
  resource_prefix                 = var.iij_name_prefix
  selenium_hub_internal_ip        = cidrhost(var.base_vm_ip_cidr, 
                                    tonumber(split(".", 
                                    split("/", var.base_vm_ip_cidr)[0])[3]) + 1)
}

data "vsphere_datacenter" "target_dc" {
  name                        = var.vsphere_datacenter
}

data "vsphere_compute_cluster" "target_cluster" {
  name                        = var.vsphere_cluster
  datacenter_id               = data.vsphere_datacenter.target_dc.id
}

data "vsphere_datastore" "target_datastore" {
  name                        = var.vsphere_datastore
  datacenter_id               = data.vsphere_datacenter.target_dc.id
}

data "vsphere_folder" "target_folder" {
  path                        = "${var.vsphere_datacenter}/vm/${var.vsphere_folder}"
}

data "vsphere_resource_pool" "target_resource_pool" {
  name                        = var.vsphere_resource_pool
  datacenter_id               = data.vsphere_datacenter.target_dc.id
}

data "vsphere_network" "target_network" {
  name                        = var.vsphere_network
  datacenter_id               = data.vsphere_datacenter.target_dc.id
}

data "vsphere_virtual_machine" "vm_template" {
  name                        = var.vsphere_vm_template_name
  datacenter_id               = data.vsphere_datacenter.target_dc.id
}

resource "vsphere_virtual_machine" "vsphere_vm" {
  count                       = var.number_vms
  name                        = tostring(count.index == 0 
                                ? "${local.resource_prefix}-master" 
                                : "${local.resource_prefix}-worker-${count.index}")
  datastore_id                = data.vsphere_datastore.target_datastore.id
  resource_pool_id            = data.vsphere_resource_pool.target_resource_pool.id
  folder                      = data.vsphere_folder.target_folder.path
  num_cpus                    = var.vm_cpu_cores
  cpu_hot_add_enabled         = var.vm_cpu_hot_add
  cpu_hot_remove_enabled      = var.vm_cpu_hot_remove  
  memory                      = var.vm_mem_size
  memory_hot_add_enabled      = var.vm_mem_hot_add
  efi_secure_boot_enabled     = var.vm_enable_efi
  firmware                    = var.vm_template_firmware
  guest_id                    = data.vsphere_virtual_machine.vm_template.guest_id
  scsi_type                   = data.vsphere_virtual_machine.vm_template.scsi_type

  network_interface {
    network_id                = data.vsphere_network.target_network.id
  }

  disk {
    label                     = "disk0"
    size                      = data.vsphere_virtual_machine.vm_template.disks[0].size
    eagerly_scrub             = data.vsphere_virtual_machine.vm_template.disks[0].eagerly_scrub
    thin_provisioned          = data.vsphere_virtual_machine.vm_template.disks[0].thin_provisioned
  }

  clone {
    template_uuid             = data.vsphere_virtual_machine.vm_template.id

    customize {
      linux_options {
        host_name             = tostring(count.index == 0 
                                ? "${local.resource_prefix}-master" 
                                : "${local.resource_prefix}-worker-${count.index}")
        domain                = ""
      }

      network_interface {
        ipv4_address          = cidrhost(var.base_vm_ip_cidr,
                                tonumber(split(".", 
                                         split("/", var.base_vm_ip_cidr)[0])[3]) 
                                         + count.index + 1)
        ipv4_netmask          = tonumber(split("/", var.base_vm_ip_cidr)[1])
      }

      ipv4_gateway            = var.vm_gateway
      dns_server_list         = [var.vm_dns]
    }
  }

  connection {
    type                      = "ssh"
    host                      = self.guest_ip_addresses[0]
    user                      = "root"
    private_key               = file("${path.root}/files/vcenter_ssh_key")
  }

  provisioner "file" {
    source                    = "${path.root}/files/"
    destination               = "/root/"
  }

  provisioner "remote-exec" {
    inline = [
      "cat /etc/os-release && uname -a",
      "bash /root/microk8s.sh",
      "microk8s config > /root/microk8s_config",
    ]
  }
}

resource "null_resource" "fetch_kubeconfig" {
  depends_on = [vsphere_virtual_machine.vsphere_vm]
  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${path.root}/files/vcenter_ssh_key root@${vsphere_virtual_machine.vsphere_vm[0].guest_ip_addresses[0]}:/root/microk8s_config ~/.kube/config"
  }
}

resource "null_resource" "install_k8s_components" {
  depends_on = [null_resource.fetch_kubeconfig]
  provisioner "local-exec" {
    command = "bash ${path.root}/k8s-cluster-config/install_k8s_components.sh"
  }
}
