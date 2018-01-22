variable "context"              { }
variable "aws_region"           { }
variable "foundry_state_bucket" { }
variable "foundry_state_key"    { }
variable "log_group"            { }
variable "vpn_private_ip"       { }
variable "vpn_dest_ip"          { }
variable "vpn_dest_tcp_port"    { }
variable "vpn_dest_udp_port"    { }
variable "vpn_dest_subnet"      { }
variable "vpn_dest_secret"      { }
variable "log_retention_days"   { default = 90 }
variable "instance_type"        { default = "t2.nano"}
variable "instance_count_min"     { default = 1 }
variable "instance_count_max"     { default = 2 }
variable "instance_count_desired" { default = 1 }
