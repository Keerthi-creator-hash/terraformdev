variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "AWS CLI profile name for target account"
  type        = string
  default     = "stavir"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "dev-api"
}

variable "vpc_cidr" {
  description = "CIDR block for new VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs for ALB/NAT"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs for ASG/RDS/ElastiCache"
  type        = list(string)
}

variable "availability_zones" {
  description = "AZs for subnets"
  type        = list(string)
}

variable "key_name" {
  description = "Name for the EC2 key pair that Terraform will create"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "EC2 instance type for ASG"
  type        = string
  default     = "t3.micro"
}

variable "asg_desired" {
  type    = number
  default = 2
}

variable "asg_min" {
  type    = number
  default = 1
}

variable "asg_max" {
  type    = number
  default = 3
}

variable "api_port" {
  description = "Application port"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/"
}

variable "db_name" {
  description = "RDS database name"
  type        = string
  default     = "devdb"
}

variable "db_username" {
  description = "RDS username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "RDS password"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS storage"
  type        = number
  default     = 20
}

variable "s3_bucket_name" {
  description = "Globally unique S3 bucket name"
  type        = string
}

variable "cache_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "domain_name" {
  description = "Domain name for ACM certificate"
  type        = string
  default     = "stavir.com"
}

variable "route53_zone_id" {
  description = "Existing public Route53 hosted zone ID to use for DNS records"
  type        = string
}
