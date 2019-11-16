provider "azurerm" {
  version = "=1.36.0"
  subscription_id = "6f406f67-316d-4611-a40c-14cbbea114da"
}

resource "azurerm_resource_group" "terraformgroup" {
    name     = "TerraResourceGroup"
    location = "northeurope"

    tags = {
        environment = "Terraform Demo"
    }
}

resource "azurerm_virtual_network" "terraformnetwork" {
    name                = "Vnet1"
    address_space       = ["10.0.0.0/16"]
    location            = "northeurope"
    resource_group_name = "${azurerm_resource_group.terraformgroup.name}"

    tags = {
        environment = "Terraform Demo"
    }
}

resource "azurerm_subnet" "terraformsubnet" {
    name                 = "Subnet1"
    resource_group_name  = "${azurerm_resource_group.terraformgroup.name}"
    virtual_network_name = "${azurerm_virtual_network.terraformnetwork.name}"
    address_prefix       = "10.0.2.0/24"
}

resource "azurerm_public_ip" "terraformpublicip" {
    name                         = "PublicIP"
    location                     = "northeurope"
    resource_group_name          = "${azurerm_resource_group.terraformgroup.name}"
    allocation_method            = "Dynamic"

    tags = {
       environment = "Terraform Demo"
    }
}

resource "azurerm_network_security_group" "terraformnsg" {
    name                = "NetworkSecurityGroup"
    location            = "northeurope"
    resource_group_name = "${azurerm_resource_group.terraformgroup.name}"
    
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "3389"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }


    tags = {
        environment = "Terraform Demo"
    }
}

resource "azurerm_network_interface" "terraformnic" {
    name                        = "NIC"
    location                    = "northeurope"
    resource_group_name         = "${azurerm_resource_group.terraformgroup.name}"
    network_security_group_id   = "${azurerm_network_security_group.terraformnsg.id}"

    ip_configuration {
        name                          = "NicConfiguration"
        subnet_id                     = "${azurerm_subnet.terraformsubnet.id}"
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = "${azurerm_public_ip.terraformpublicip.id}"
    }

    tags = {
        environment = "Terraform Demo"
    }
}

resource "azurerm_virtual_machine" "terraformvm" {
    name                  = "TerraVM"
    location              = "northeurope"
    resource_group_name   = "${azurerm_resource_group.terraformgroup.name}"
    network_interface_ids =  ["${azurerm_network_interface.terraformnic.id}"]
  
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "OsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

   storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter-Core"
    version   = "latest"
  }

    os_profile {
        computer_name  = "terravm"
        admin_username = "azureuser"
        admin_password = "${var.admin_password}"
    }

    tags = {
        environment = "Terraform Demo"
    }
}

resource "azurerm_virtual_machine_extension" "domjoin" {
name = "domjoin"
location = "northeurope"
resource_group_name = "${azurerm_resource_group.terraformgroup.name}"
virtual_machine_name = "terravm"
publisher = "Microsoft.Compute"
type = "JsonADDomainExtension"
type_handler_version = "1.3"
settings = <<SETTINGS
{
"Name": "deise.com",
"OUPath": "OU=Servers,DC=deise,DC=com",
"User": "deise.com\\pr_admin",
"Restart": "true",
"Options": "3"
}
SETTINGS
protected_settings = <<PROTECTED_SETTINGS
{
"Password": "${var.admin_password}"
}
PROTECTED_SETTINGS
depends_on = ["azurerm_virtual_machine.terraformvm"]
}   