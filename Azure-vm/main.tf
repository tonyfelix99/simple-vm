terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "simple-vm-rg"  # Use resource group name from config
  location = "eastus"        # Use location from config
  
  tags = {
    Environment = "Production"              # Tag for environment
    CreatedBy   = "AI-DevOps-Agent"        # Tag to track creator
    CostCenter  = "IT-Infrastructure"      # Cost center tag
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = "simple-vnet"  # VNet name from config
  address_space       = ["10.0.0.0/16"] # VNet CIDR block
  location            = azurerm_resource_group.rg.location  # Use RG location
  resource_group_name = azurerm_resource_group.rg.name      # Use RG name

  tags = azurerm_resource_group.rg.tags  # Inherit tags from resource group
}

resource "azurerm_subnet" "subnet" {
  name                 = "simple-subnet"  # Subnet name from config
  address_prefixes     = ["10.0.1.0/24"] # Subnet CIDR
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
}

resource "azurerm_network_security_group" "nsg" {
  name                = "Azure-vm-nsg"  # NSG named after VM with suffix
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"          # Rule to allow SSH traffic
    priority                   = 1001           # Rule priority
    direction                  = "Inbound"      # Incoming traffic
    access                     = "Allow"        # Allow traffic
    protocol                   = "Tcp"          # TCP protocol
    source_port_range          = "*"            # Any source port
    destination_port_range     = "22"           # Destination port 22 (SSH)
    source_address_prefix      = "*"            # From any IP
    destination_address_prefix = "*"            # To any IP
  }

  tags = azurerm_resource_group.rg.tags
}

resource "azurerm_network_interface" "nic" {
  name                = "simple-nic"  # NIC name from config
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id  # Link to subnet resource
    private_ip_address_allocation = "Dynamic"                 # Assign IP dynamically
  }

  tags = azurerm_resource_group.rg.tags
}

resource "azurerm_network_interface_security_group_association" "nsg_association" {
  network_interface_id      = azurerm_network_interface.nic.id  # Associate NIC with NSG
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "Azure-vm"            # VM name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"            # VM size/type
  admin_username      = "azureuser"          # Admin username
  admin_password      = "P@ssw0rd1234!"          # Admin password
  disable_password_authentication = false                  # Password auth enabled

  network_interface_ids = [
    azurerm_network_interface.nic.id,                      # Attach NIC
  ]

  os_disk {
    caching              = "ReadWrite"                     # Disk caching mode
    storage_account_type = "Standard_LRS"      # Disk type
    disk_size_gb         = 40        # Disk size in GB
  }

  source_image_reference {
    publisher = "Canonical"              # Image publisher
    offer     = "0001-com-ubuntu-server-focal"                  # Image offer
    sku       = "20_04-lts"                    # Image SKU
    version   = "latest"                # Image version
  }

  tags = azurerm_resource_group.rg.tags                    # Inherit tags
}