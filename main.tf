# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}
provider "azurerm" {
  features {}
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "rg-atividadeinfracloud" {
    name     = "rgaulainfracloud"
    location = "West US 2"

    tags = {
        environment = "Terraform Demo"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "virtualnetworkaulainfracloud" {
    name                = "myVnet"
    address_space       = ["10.0.0.0/16"]
    location            = azurerm_resource_group.rg-atividadeinfracloud.location
    resource_group_name = azurerm_resource_group.rg-atividadeinfracloud.name

    tags = {
        environment = "Terraform Demo"
    }
}

# Create subnet
resource "azurerm_subnet" "subnetaulainfracloud" {
    name                 = "mySubnet"
    resource_group_name  = azurerm_resource_group.rg-atividadeinfracloud.name
    virtual_network_name = azurerm_virtual_network.virtualnetworkaulainfracloud.name
    address_prefixes       = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "ip-aulainfracloud" {
    name                         = "myPublicIP"
    location                     = azurerm_resource_group.rg-atividadeinfracloud.location
    resource_group_name          = azurerm_resource_group.rg-atividadeinfracloud.name
    allocation_method            = "Static"

    tags = {
        environment = "Terraform Demo"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "networksegurityaulainfracloud" {
    name                = "myNetworkSecurityGroup"
    location            = azurerm_resource_group.rg-atividadeinfracloud.location
    resource_group_name = azurerm_resource_group.rg-atividadeinfracloud.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "web"
        priority                   = 1003
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
  }

    tags = {
        environment = "Terraform Demo"
    }
}




# Create network interface
resource "azurerm_network_interface" "nic-aulainfracloud" {
    name                      = "myNIC"
    location                  = azurerm_resource_group.rg-atividadeinfracloud.location
    resource_group_name       = azurerm_resource_group.rg-atividadeinfracloud.name

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.subnetaulainfracloud.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.ip-aulainfracloud.id
    }

    tags = {
        environment = "Terraform Demo"
    }
}

resource "azurerm_network_interface_security_group_association" "nic-networksegurityaulainfracloud" {
  network_interface_id      = azurerm_network_interface.nic-aulainfracloud.id
  network_security_group_id = azurerm_network_security_group.networksegurityaulainfracloud.id
}

resource "azurerm_virtual_machine" "vm-aulainfracloud" {
  name                  = "vm-aula"
  location              = azurerm_resource_group.rg-atividadeinfracloud.location
  resource_group_name   = azurerm_resource_group.rg-atividadeinfracloud.name
  network_interface_ids = [azurerm_network_interface.nic-aulainfracloud.id]
  vm_size               = "Standard_DS1_v2"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
  
  tags = {
    environment = "staging"
  }
}


data "azurerm_public_ip" "ip-aula"{
    name = azurerm_public_ip.ip-aulainfracloud.name
    resource_group_name = azurerm_resource_group.rg-atividadeinfracloud.name
}

resource "null_resource" "install-apache" {
  connection {
    type = "ssh"
    host = data.azurerm_public_ip.ip-aula.ip_address
    user = "testadmin"
    password = "Password1234!"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y apache2",
    ]
  }

  depends_on = [
    azurerm_virtual_machine.vm-aulainfracloud
  ]
}

