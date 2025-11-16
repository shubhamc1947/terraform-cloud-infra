variable "project_name" {
  description = "Base name for all resources (e.g., travel-infra)"
  type        = string
  default     = "travel-infra"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "List of public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "List of private subnet CIDRs"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "instance_type" {
  description = "Instance type for EC2"
  type        = string
  default     = "t3.micro"
}

variable "api_port" {
  description = "Port that API listens on"
  type        = number
  default     = 8080
}

variable "my_ip" {
  description = "Your IP address for SSH access (x.x.x.x/32)"
  type        = string
  default     = "0.0.0.0/0"
}

###################################################
# SSH Key Variables (Using existing tarmac.pem)
###################################################
variable "ssh_public_key_path" {
  description = "Path to your existing SSH public key (.pub) file"
  type        = string
  default     = "C:/Users/user/.ssh/tarmac.pub"
}
