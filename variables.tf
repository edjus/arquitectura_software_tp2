variable "access_key" {
}

variable "secret_key" {
}

variable "datadog_key" {
}

variable "region" {
  default = "us-east-1"
}

variable "availability_zone" {
  default = "us-east-1a"
}

variable "root" {
  default = "/home/ec2-user/app"
}

variable "key_pair_name" {
  default = "arquitectura"
}

variable "private_key_location" {
  default = "~/.ssh/arquitectura.pem"
}

variable "vpc_id" {
  default = "vpc-b08cbbcb"
}

variable "ami_id" {
  default = "ami-0d5eff06f840b45e9"
}

variable "node_version" {
  default = "10.18.0"
}

