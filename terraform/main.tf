# Resource Group
resource "azurerm_resource_group" "k8s" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Virtual Network
resource "azurerm_virtual_network" "k8s" {
  name                = "${var.resource_group_name}-vnet"
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name
  tags                = var.tags
}

# Subnet
resource "azurerm_subnet" "k8s" {
  name                 = "${var.resource_group_name}-subnet"
  resource_group_name  = azurerm_resource_group.k8s.name
  virtual_network_name = azurerm_virtual_network.k8s.name
  address_prefixes     = [var.subnet_address_prefix]
}

# Network Security Group
resource "azurerm_network_security_group" "k8s" {
  name                = "${var.resource_group_name}-nsg"
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name
  tags                = var.tags

  # SSH Access
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

  # Kubernetes API Server
  security_rule {
    name                       = "Kubernetes-API"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # NodePort Services
  security_rule {
    name                       = "NodePort"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "30000-32767"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # HTTP
  security_rule {
    name                       = "HTTP"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # HTTPS
  security_rule {
    name                       = "HTTPS"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Kubelet API
  security_rule {
    name                       = "Kubelet-API"
    priority                   = 1006
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "10250"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # etcd
  security_rule {
    name                       = "etcd"
    priority                   = 1007
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "2379-2380"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

# Availability Set
resource "azurerm_availability_set" "k8s" {
  name                         = "${var.resource_group_name}-avset"
  location                     = azurerm_resource_group.k8s.location
  resource_group_name          = azurerm_resource_group.k8s.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 5
  managed                      = true
  tags                         = var.tags
}

# Public IP for Load Balancer
resource "azurerm_public_ip" "lb" {
  name                = "${var.resource_group_name}-lb-pip"
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Load Balancer
resource "azurerm_lb" "k8s" {
  name                = "${var.resource_group_name}-lb"
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "LoadBalancerFrontEnd"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

# Load Balancer Backend Pool
resource "azurerm_lb_backend_address_pool" "k8s" {
  loadbalancer_id = azurerm_lb.k8s.id
  name            = "BackendPool"
}

# Load Balancer Probe
resource "azurerm_lb_probe" "k8s" {
  loadbalancer_id = azurerm_lb.k8s.id
  name            = "http-probe"
  protocol        = "Tcp"
  port            = 80
}

# Load Balancer Rule for HTTP
resource "azurerm_lb_rule" "http" {
  loadbalancer_id                = azurerm_lb.k8s.id
  name                           = "HTTP"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.k8s.id]
  probe_id                       = azurerm_lb_probe.k8s.id
}

# Random suffix for storage account name uniqueness
resource "random_string" "storage_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Storage Account for Blob Storage
resource "azurerm_storage_account" "k8s" {
  name                     = substr(lower(replace("${var.resource_group_name}st${random_string.storage_suffix.result}", "-", "")), 0, 24)
  resource_group_name      = azurerm_resource_group.k8s.name
  location                 = azurerm_resource_group.k8s.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication
  tags                     = var.tags
}

# Storage Container
resource "azurerm_storage_container" "k8s" {
  name                  = "kubernetes-data"
  storage_account_name  = azurerm_storage_account.k8s.name
  container_access_type = "private"
}

# Public IPs for VMs
resource "azurerm_public_ip" "control_plane" {
  name                = "${var.resource_group_name}-cp-pip"
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_public_ip" "worker" {
  count               = var.worker_count
  name                = "${var.resource_group_name}-worker-${count.index + 1}-pip"
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Network Interfaces
resource "azurerm_network_interface" "control_plane" {
  name                = "${var.resource_group_name}-cp-nic"
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.k8s.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.control_plane.id
  }
}

resource "azurerm_network_interface" "worker" {
  count               = var.worker_count
  name                = "${var.resource_group_name}-worker-${count.index + 1}-nic"
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.k8s.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.worker[count.index].id
  }
}

# Associate NICs with NSG
resource "azurerm_network_interface_security_group_association" "control_plane" {
  network_interface_id      = azurerm_network_interface.control_plane.id
  network_security_group_id = azurerm_network_security_group.k8s.id
}

resource "azurerm_network_interface_security_group_association" "worker" {
  count                     = var.worker_count
  network_interface_id      = azurerm_network_interface.worker[count.index].id
  network_security_group_id = azurerm_network_security_group.k8s.id
}

# Associate Worker NICs with Load Balancer Backend Pool
resource "azurerm_network_interface_backend_address_pool_association" "worker" {
  count                   = var.worker_count
  network_interface_id    = azurerm_network_interface.worker[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.k8s.id
}

# Control Plane VM
resource "azurerm_linux_virtual_machine" "control_plane" {
  name                  = "${var.resource_group_name}-control-plane"
  location              = azurerm_resource_group.k8s.location
  resource_group_name   = azurerm_resource_group.k8s.name
  network_interface_ids = [azurerm_network_interface.control_plane.id]
  size                  = var.control_plane_vm_size
  availability_set_id   = azurerm_availability_set.k8s.id
  tags                  = var.tags

  admin_username = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    name                 = "${var.resource_group_name}-cp-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init-control-plane.yaml", {
    admin_username = var.admin_username
  }))
}

# Worker VMs
resource "azurerm_linux_virtual_machine" "worker" {
  count                 = var.worker_count
  name                  = "${var.resource_group_name}-worker-${count.index + 1}"
  location              = azurerm_resource_group.k8s.location
  resource_group_name   = azurerm_resource_group.k8s.name
  network_interface_ids = [azurerm_network_interface.worker[count.index].id]
  size                  = var.worker_vm_size
  availability_set_id   = azurerm_availability_set.k8s.id
  tags                  = var.tags

  admin_username = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    name                 = "${var.resource_group_name}-worker-${count.index + 1}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init-worker.yaml", {
    admin_username = var.admin_username
  }))
}

# Role Assignment for VMs to access Storage
resource "azurerm_role_assignment" "control_plane_storage" {
  scope                = azurerm_storage_account.k8s.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_virtual_machine.control_plane.identity[0].principal_id
}

resource "azurerm_role_assignment" "worker_storage" {
  count                = var.worker_count
  scope                = azurerm_storage_account.k8s.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_virtual_machine.worker[count.index].identity[0].principal_id
}
