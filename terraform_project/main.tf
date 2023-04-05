
resource "azurerm_resource_group" "demo1" {
  name     = var.hdfc_resource_group_name
  location = var.location_resource_group
}



resource "azurerm_virtual_network" "hdfc_prod_vnet" {
  name                = "hdfc-prod-vnet"
  resource_group_name = azurerm_resource_group.demo1.name
  location            = azurerm_resource_group.demo1.location
  address_space       = ["192.168.0.0/24"]
  dns_servers         = []
}

resource "azurerm_subnet" "hdfc_subnet" {
  name                                           = "hdfc-prod-vm"
  address_prefixes                               = ["192.168.0.0/28"]
  virtual_network_name                           = azurerm_virtual_network.hdfc_prod_vnet.name
  resource_group_name                            = azurerm_resource_group.demo1.name
  enforce_private_link_endpoint_network_policies = true
  service_endpoints                              = ["Microsoft.Sql", "Microsoft.Storage"]

}

resource "azurerm_network_interface" "app_interface1" {
  name                = "app-interface1"
  location            = azurerm_resource_group.demo1.location
  resource_group_name = azurerm_resource_group.demo1.name


  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.hdfc_subnet.id
    private_ip_address_allocation = "Dynamic"
  
  }
}
  

  resource "azurerm_network_security_group" "hdfc_NSG" {
    name                = "hdfc-subnet-nsg"
    resource_group_name = azurerm_resource_group.demo1.name
    location            = azurerm_resource_group.demo1.location

  }

  resource "azurerm_network_security_rule" "hdfc-subnet-nsg1" {
    name                       = "hdfc-subnet-nsg"
    priority                   = "100"
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "80"
    destination_port_range     = "80"
    source_address_prefix      = ""
    destination_address_prefix = ""

    resource_group_name         = azurerm_resource_group.demo1.name
    network_security_group_name = azurerm_network_security_group.hdfc_NSG.name

  }


  resource "azurerm_public_ip" "load_ip" {
    name                = "load-ip"
    location            = azurerm_resource_group.demo1.location
    resource_group_name = azurerm_resource_group.demo1.name
    allocation_method   = "Static"
    sku                 = "Standard"
  }

  //  creating the Azure Load Balancer


  resource "azurerm_lb" "app_balancer" {
    name                = "app-balancer"
    location            = azurerm_resource_group.demo1.location
    resource_group_name = azurerm_resource_group.demo1.name
    sku                 = "Standard"
    sku_tier            = "Regional"
    frontend_ip_configuration {
      name                 = "frontend-ip"
      public_ip_address_id = azurerm_public_ip.load_ip.id
    }


  }

  // defining the backend pool
  resource "azurerm_lb_backend_address_pool" "scalesetpool" {
    loadbalancer_id = azurerm_lb.app_balancer.id
    name            = "scalesetpool"

  }

  // defining the Health Probe
  resource "azurerm_lb_probe" "Probe1" {
    loadbalancer_id     = azurerm_lb.app_balancer.id
    name                = "probe1"
    port                = 80
    protocol            = "Tcp"

  }

  // Defining the Load Balancing Rule
  resource "azurerm_lb_rule" "Rule1" {
    loadbalancer_id                = azurerm_lb.app_balancer.id
    name                           = "Rule1"
    protocol                       = "Tcp"
    frontend_port                  = 80
    backend_port                   = 80
    frontend_ip_configuration_name = "frontend-ip"
    backend_address_pool_ids       = [azurerm_lb_backend_address_pool.scalesetpool.id]
  }

 



resource "azurerm_public_ip" "traffic_ip" {
  name                = azurerm_public_ip.load_ip.name
  location            = azurerm_resource_group.demo1.location
  resource_group_name = azurerm_resource_group.demo1.name
  allocation_method   = "Static"
  domain_name_label   = "hdfc-public-ip"
}


resource "azurerm_traffic_manager_profile" "hdfctm" {
  name                   = "hdfctrafficmanager"
  resource_group_name    = azurerm_resource_group.demo1.name
  traffic_routing_method = "Weighted"

  dns_config {
    relative_name = "hdfc-profile"
    ttl           = 100
  }

  monitor_config {
    protocol                     = "HTTP"
    port                         = 80
    path                         = "/"
    interval_in_seconds          = 30
    timeout_in_seconds           = 9
    tolerated_number_of_failures = 3
  }
}
 
 
 
 
 
 
 
 
 
 
 
 
 # crating a VPN Gateway
 
 resource "azurerm_virtual_network_gateway" "hdfcvng" {
  name                = "prodhdfc"
  location            = azurerm_resource_group.demo1.location
  resource_group_name = azurerm_resource_group.demo1.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = "Basic"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.load_ip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.hdfc_subnet.id
  }

  vpn_client_configuration {
    address_space = ["10.2.0.0/24"]

    root_certificate {
      name = "DigiCert-Federated-ID-Root-CA"

      public_cert_data = <<EOF
MIIDuzCCAqOgAwIBAgIQCHTZWCM+IlfFIRXIvyKSrjANBgkqhkiG9w0BAQsFADBn
MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
d3cuZGlnaWNlcnQuY29tMSYwJAYDVQQDEx1EaWdpQ2VydCBGZWRlcmF0ZWQgSUQg
Um9vdCBDQTAeFw0xMzAxMTUxMjAwMDBaFw0zMzAxMTUxMjAwMDBaMGcxCzAJBgNV
BAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdp
Y2VydC5jb20xJjAkBgNVBAMTHURpZ2lDZXJ0IEZlZGVyYXRlZCBJRCBSb290IENB
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvAEB4pcCqnNNOWE6Ur5j
QPUH+1y1F9KdHTRSza6k5iDlXq1kGS1qAkuKtw9JsiNRrjltmFnzMZRBbX8Tlfl8
zAhBmb6dDduDGED01kBsTkgywYPxXVTKec0WxYEEF0oMn4wSYNl0lt2eJAKHXjNf
GTwiibdP8CUR2ghSM2sUTI8Nt1Omfc4SMHhGhYD64uJMbX98THQ/4LMGuYegou+d
GTiahfHtjn7AboSEknwAMJHCh5RlYZZ6B1O4QbKJ+34Q0eKgnI3X6Vc9u0zf6DH8
Dk+4zQDYRRTqTnVO3VT8jzqDlCRuNtq6YvryOWN74/dq8LQhUnXHvFyrsdMaE1X2
DwIDAQABo2MwYTAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBhjAdBgNV
HQ4EFgQUGRdkFnbGt1EWjKwbUne+5OaZvRYwHwYDVR0jBBgwFoAUGRdkFnbGt1EW
jKwbUne+5OaZvRYwDQYJKoZIhvcNAQELBQADggEBAHcqsHkrjpESqfuVTRiptJfP
9JbdtWqRTmOf6uJi2c8YVqI6XlKXsD8C1dUUaaHKLUJzvKiazibVuBwMIT84AyqR
QELn3e0BtgEymEygMU569b01ZPxoFSnNXc7qDZBDef8WfqAV/sxkTi8L9BkmFYfL
uGLOhRJOFprPdoDIUBB+tmCl3oDcBy3vnUeOEioz8zAkprcb3GHwHAK+vHmmfgcn
WsfMLH4JCLa/tRYL+Rw/N3ybCkDp00s0WUZ+AoDywSl0Q/ZEnNY0MsFiw6LyIdbq
M/s/1JRtO3bDSzD9TazRVzn2oBqzSa8VgIo5C1nOnoAKJTlsClJKvIhnRlaLQqk=
EOF

    }

  }
 
 }
 
 
 # creating vpn site-to-site

 resource "azurerm_local_network_gateway" "hdfclocal" {
  name                = "hdfclocaldemo"
  location            = azurerm_resource_group.demo1.location
  resource_group_name =  azurerm_resource_group.demo1.name
  gateway_address     = "168.62.225.23"
  address_space       = ["10.1.1.0/26"]
}





resource "azurerm_virtual_network_gateway_connection" "hdfcpremise" {
  name                = "prodhdfcpremise"
  location            = azurerm_resource_group.demo1.location
  resource_group_name = azurerm_resource_group.demo1.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.hdfcvng.id
  local_network_gateway_id   = azurerm_local_network_gateway.hdfclocal.id

  
}


# creating point_to_site_vpn_gateway

resource "azurerm_virtual_wan" "p2shdfc" {
  name                = "hdfcwan"
  resource_group_name = azurerm_resource_group.demo1.name
  location            = azurerm_resource_group.demo1.location
}

resource "azurerm_virtual_hub" "hdfchub" {
  name                = "hdfcvhub"
  resource_group_name = azurerm_resource_group.demo1.name
  location            = azurerm_resource_group.demo1.location
  virtual_wan_id      = azurerm_virtual_wan.p2shdfc.id
  address_prefix      = "10.0.0.0/24"
}

resource "azurerm_vpn_server_configuration" "hdfcserver" {
  name                     = "vpnhdfcconfig"
  resource_group_name      = azurerm_resource_group.demo1.name
  location                 = azurerm_resource_group.demo1.location
  vpn_authentication_types = ["Certificate"]


 client_root_certificate {
    name             = "DigiCert-Federated-ID-Root-CA"
    public_cert_data = <<EOF
MIIDuzCCAqOgAwIBAgIQCHTZWCM+IlfFIRXIvyKSrjANBgkqhkiG9w0BAQsFADBn
MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
d3cuZGlnaWNlcnQuY29tMSYwJAYDVQQDEx1EaWdpQ2VydCBGZWRlcmF0ZWQgSUQg
Um9vdCBDQTAeFw0xMzAxMTUxMjAwMDBaFw0zMzAxMTUxMjAwMDBaMGcxCzAJBgNV
BAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdp
Y2VydC5jb20xJjAkBgNVBAMTHURpZ2lDZXJ0IEZlZGVyYXRlZCBJRCBSb290IENB
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvAEB4pcCqnNNOWE6Ur5j
QPUH+1y1F9KdHTRSza6k5iDlXq1kGS1qAkuKtw9JsiNRrjltmFnzMZRBbX8Tlfl8
zAhBmb6dDduDGED01kBsTkgywYPxXVTKec0WxYEEF0oMn4wSYNl0lt2eJAKHXjNf
GTwiibdP8CUR2ghSM2sUTI8Nt1Omfc4SMHhGhYD64uJMbX98THQ/4LMGuYegou+d
GTiahfHtjn7AboSEknwAMJHCh5RlYZZ6B1O4QbKJ+34Q0eKgnI3X6Vc9u0zf6DH8
Dk+4zQDYRRTqTnVO3VT8jzqDlCRuNtq6YvryOWN74/dq8LQhUnXHvFyrsdMaE1X2
DwIDAQABo2MwYTAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBhjAdBgNV
HQ4EFgQUGRdkFnbGt1EWjKwbUne+5OaZvRYwHwYDVR0jBBgwFoAUGRdkFnbGt1EW
jKwbUne+5OaZvRYwDQYJKoZIhvcNAQELBQADggEBAHcqsHkrjpESqfuVTRiptJfP
9JbdtWqRTmOf6uJi2c8YVqI6XlKXsD8C1dUUaaHKLUJzvKiazibVuBwMIT84AyqR
QELn3e0BtgEymEygMU569b01ZPxoFSnNXc7qDZBDef8WfqAV/sxkTi8L9BkmFYfL
uGLOhRJOFprPdoDIUBB+tmCl3oDcBy3vnUeOEioz8zAkprcb3GHwHAK+vHmmfgcn
WsfMLH4JCLa/tRYL+Rw/N3ybCkDp00s0WUZ+AoDywSl0Q/ZEnNY0MsFiw6LyIdbq
M/s/1JRtO3bDSzD9TazRVzn2oBqzSa8VgIo5C1nOnoAKJTlsClJKvIhnRlaLQqk=
EOF
  }
 
}

 resource "azurerm_point_to_site_vpn_gateway" "hdfcvpng" {
  name                        = "hdfc-vpn-gateway"
  location                    = azurerm_resource_group.demo1.location
  resource_group_name         = azurerm_resource_group.demo1.name
  virtual_hub_id              = azurerm_virtual_hub.hdfchub.id
  vpn_server_configuration_id = azurerm_vpn_server_configuration.hdfcserver.id
  scale_unit                  = 1
  connection_configuration {
    name = "hdfc-gateway-config"

    vpn_client_address_pool {
      address_prefixes = [
        "10.0.2.0/24"
      ]
    }
  }
 
 }
 
 #creating azure logic app standard with app service plan

resource "azurerm_storage_account" "hdfcstorage" {
  name                     = var.storage1
  resource_group_name      = azurerm_resource_group.demo1.name
  location                 = var.location
  access_tier              = var.access_tier
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type
  account_kind             = var.account_kind
}

resource "azurerm_app_service_plan" "logictest" {
  name                = "azure-logictest-service-plan"
  location            = azurerm_resource_group.demo1.location
  resource_group_name = azurerm_resource_group.demo1.name
  kind                = "elastic"


  sku {
    tier = "WorkflowStandard"
    size = "WS1"
  }
}

resource "azurerm_logic_app_standard" "azlogicapp" {
  name                       = "test-azure-logicapp"
  location                   = azurerm_resource_group.demo1.location
  resource_group_name        = azurerm_resource_group.demo1.name
  app_service_plan_id        = azurerm_app_service_plan.logictest.id
  storage_account_name       = azurerm_storage_account.hdfcstorage.name
  storage_account_access_key = azurerm_storage_account.hdfcstorage.primary_access_key
}


# creating Windows Function App Slot

resource "azurerm_service_plan" "functionapp" {
  name                = "-app-service-plan2"
  resource_group_name = azurerm_resource_group.demo1.name
  location            = azurerm_resource_group.demo1.location
  os_type             = "Windows"
  sku_name            = "Y1"
}

resource "azurerm_windows_function_app" "windowsapp" {
  name                 = "hdfc-windows-function-app"
  resource_group_name  = azurerm_resource_group.demo1.name
  location             = azurerm_resource_group.demo1.location
  storage_account_name = azurerm_storage_account.hdfcstorage.name
  service_plan_id      = azurerm_service_plan.functionapp.id

  site_config {}
}

resource "azurerm_windows_function_app_slot" "windowsslot" {
  name                 = "hdfc-slot"
  function_app_id      = azurerm_windows_function_app.windowsapp.id
  storage_account_name = azurerm_storage_account.hdfcstorage.name

  site_config {}
}












 
 
 
   /*resource "azurerm_windows_virtual_machine_scale_set" "vmsc" {
    name                = "vmss"
    resource_group_name = azurerm_resource_group.demo1.name
    location            = azurerm_resource_group.demo1.location
    sku                 = "Standard_F2"
    instances           = 2
    admin_password      = "Azure@123"
    admin_username      = "vmuser"

    source_image_reference {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2019-Datacenter"
      version   = "latest"
    }

    os_disk {
      storage_account_type = "Standard_LRS"
      caching              = "ReadWrite"
    }



    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.hdfc-prod-vm.id
    }
  }

*/