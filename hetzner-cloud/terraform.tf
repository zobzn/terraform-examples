# Token variable
variable "hcloud_token" {
  type = string
  # default = "here-is-api-token"
}

# Ssh key fingerprint variable
variable "hcloud_ssh_key_fingerprint" {
  type = string
  # default = "here-is-ssh-key-fingerprint"
}

# Define Hetzner provider
provider "hcloud" {
  token = "${var.hcloud_token}"
}

# Obtain ssh key data
data "hcloud_ssh_key" "ssh_key" {
  fingerprint = "${var.hcloud_ssh_key_fingerprint}"
}

# Create an Ubuntu 18.04 server
resource "hcloud_server" "ubuntu18" {
  name        = "ubuntu18"
  image       = "ubuntu-18.04"
  server_type = "cx11"
  ssh_keys    = ["${data.hcloud_ssh_key.ssh_key.id}"]
}

# Create Debian 10 server
resource "hcloud_server" "debian10" {
  name        = "debian10"
  image       = "debian-10"
  server_type = "cx11"
  ssh_keys    = ["${data.hcloud_ssh_key.ssh_key.id}"]
}

# Create CentOS 8 server
resource "hcloud_server" "centos8" {
  name        = "centos8"
  image       = "centos-8"
  server_type = "cx11"
  ssh_keys    = ["${data.hcloud_ssh_key.ssh_key.id}"]
}

# Output server IPs
output "server_ip_ubuntu18" {
  value = "${hcloud_server.ubuntu18.ipv4_address}"
}

output "server_ip_debian10" {
  value = "${hcloud_server.debian10.ipv4_address}"
}

output "server_ip_centos8" {
  value = "${hcloud_server.centos8.ipv4_address}"
}
