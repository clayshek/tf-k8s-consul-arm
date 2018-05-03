# Terraform Variables
# Customize parameters in this file specific to your deployment.
# Sensitive data (passwords) can be supplied here, or alternatively supplied inline when applying config:
# terraform apply -var 'ddclient_password=PASSWORD' 

# Container image to use

image_name = "clayshek/consul-arm:latest"

# Consul cluster size

consul_count = "3"

# PERSISTENT VOLUME

nfs_server = "192.168.1.20"

# See README for how the NFS vol setup should be configured
vol_path = "/mnt/usbdrive1/consul-data"

storage_capacity = "750Mi"
