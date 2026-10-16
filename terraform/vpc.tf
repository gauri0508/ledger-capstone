# Network layer for EKS. Compared with Session 19 the differences are:
#   * two AZs (EKS refuses a cluster whose subnets are all in one AZ),
#   * a NAT Gateway so the private subnets (worker nodes) can pull images and
#     reach the EKS API without being reachable from the internet,
#   * the kubernetes.io/* subnet tags that the AWS load-balancer controller
#     and the in-tree cloud provider use to decide where to put load balancers.
# Every arrow is an implicit dependency (attribute reference); no depends_on.

locals {
  az_count = length(var.azs)
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # EKS requires both DNS flags: pods resolve the
  enable_dns_hostnames = true # cluster endpoint and nodes register by hostname

  tags = { Name = "${var.project_name}-${var.environment}-vpc" }
}

# ---- public subnets: NAT Gateway + internet-facing load balancers -------------

resource "aws_subnet" "public" {
  count = local.az_count

  vpc_id                  = aws_vpc.main.id # <- implicit dependency on the VPC
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-public-${var.azs[count.index]}"
    Tier = "public"
    # "put internet-facing Services of type LoadBalancer / ALB Ingress here"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# ---- private subnets: the worker nodes ----------------------------------------

resource "aws_subnet" "private" {
  count = local.az_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-${var.environment}-private-${var.azs[count.index]}"
    Tier = "private"
    # "put internal load balancers here"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# ---- internet gateway + one NAT gateway ---------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${var.project_name}-${var.environment}-igw" }
}

# One NAT Gateway in the first public subnet. One (not one per AZ) is the
# dev trade-off: ~$0.045/h instead of ~$0.09/h, at the cost of AZ "b" losing
# outbound internet if AZ "a" goes down. Prod would use count = local.az_count.
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = { Name = "${var.project_name}-${var.environment}-nat-eip" }

  # The EIP can only be attached to something in the VPC once the IGW exists.
  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # NAT must sit in a PUBLIC subnet

  tags = { Name = "${var.project_name}-${var.environment}-nat" }

  depends_on = [aws_internet_gateway.main]
}

# ---- route tables -------------------------------------------------------------

# Public: 0.0.0.0/0 -> IGW. The "local" route for the VPC CIDR is implicit.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id # <- implicit dependency on the IGW
  }

  tags = { Name = "${var.project_name}-${var.environment}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count = local.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private: 0.0.0.0/0 -> NAT. Nodes can go out (image pulls, EKS API, apt),
# nothing can come in.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id # <- implicit dependency on the NAT
  }

  tags = { Name = "${var.project_name}-${var.environment}-private-rt" }
}

resource "aws_route_table_association" "private" {
  count = local.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ---- additional cluster security group ----------------------------------------

# EKS creates its own "cluster security group" that already allows all traffic
# between the control plane and the nodes. This extra one is attached to the
# control-plane ENIs so that a later rule (e.g. "allow 443 from the office
# VPN") has a Terraform-managed place to live without touching the EKS-owned SG.
resource "aws_security_group" "cluster" {
  name        = "${var.project_name}-${var.environment}-eks-cluster-sg"
  description = "Additional security group for the EKS control plane ENIs"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-${var.environment}-eks-cluster-sg" }
}
