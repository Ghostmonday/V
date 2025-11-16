variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "vibez"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "instance_count" {
  description = "Number of EC2 instances"
  type        = number
  default     = 1
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 20
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production!
}

# Database variables
variable "create_rds" {
  description = "Create RDS PostgreSQL instance"
  type        = bool
  default     = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "vibez"
  sensitive   = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "external_db_host" {
  description = "External database host (if not creating RDS)"
  type        = string
  default     = ""
}

# Redis variables
variable "create_redis" {
  description = "Create ElastiCache Redis cluster"
  type        = bool
  default     = true
}

variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_nodes" {
  description = "Number of Redis cache nodes"
  type        = number
  default     = 1
}

variable "external_redis_host" {
  description = "External Redis host (if not creating ElastiCache)"
  type        = string
  default     = ""
}

variable "external_redis_port" {
  description = "External Redis port"
  type        = number
  default     = 6379
}

# Load Balancer
variable "create_alb" {
  description = "Create Application Load Balancer"
  type        = bool
  default     = false
}

# Application
variable "github_repo" {
  description = "GitHub repository URL"
  type        = string
  default     = "https://github.com/Ghostmonday/VibeZ.git"
}

