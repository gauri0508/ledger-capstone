# ---- where to run -----------------------------------------------------------

variable "use_localstack" {
  description = "true = AWS provider talks to LocalStack (mocked, free, no account; EKS calls will fail there). false = real AWS."
  type        = bool
  default     = true
}

variable "localstack_endpoint" {
  description = "LocalStack edge URL; ignored when use_localstack = false."
  type        = string
  default     = "http://localhost:4566"
}

variable "aws_region" {
  description = "Region for every regional resource (VPC, EKS)."
  type        = string
  default     = "ap-south-1"
}

# ---- naming -----------------------------------------------------------------

variable "project_name" {
  description = "Short name used in resource names and the Project tag."
  type        = string
  default     = "ledger"
}

variable "environment" {
  description = "Environment tag / name suffix (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Extra tags merged into every resource via provider default_tags."
  type        = map(string)
  default     = {}
}

# ---- network ----------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR such as 10.0.0.0/16."
  }
}

variable "azs" {
  description = "Availability zones to spread the subnets over. EKS needs subnets in at least two AZs."
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]

  validation {
    condition     = length(var.azs) >= 2
    error_message = "azs must list at least two availability zones (EKS requires subnets in >= 2 AZs)."
  }
}

variable "public_subnet_cidrs" {
  description = "One public subnet CIDR per AZ (same order as azs). Load balancers and the NAT Gateway live here."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "One private subnet CIDR per AZ (same order as azs). The EKS worker nodes live here."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

# ---- eks --------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the EKS cluster. Also used in the kubernetes.io/cluster/<name> subnet tags."
  type        = string
  default     = "ledger-dev"
}

variable "cluster_version" {
  description = "Kubernetes version of the control plane (the managed node group follows it)."
  type        = string
  default     = "1.31"
}

variable "node_instance_types" {
  description = "Instance types for the managed node group. t3.medium (2 vCPU / 4 GiB) is the smallest size that comfortably runs the Ledger pods plus the system add-ons."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 3

  validation {
    condition     = var.node_max_size >= var.node_desired_size && var.node_desired_size >= var.node_min_size
    error_message = "node sizes must satisfy min <= desired <= max."
  }
}
