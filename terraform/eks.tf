# EKS = a managed Kubernetes control plane (AWS runs the API server / etcd)
# plus a managed node group (AWS runs an Auto Scaling Group of EC2 instances
# that join the cluster). Both need an IAM role: the control plane needs one
# to create ENIs / load balancers in my VPC, the nodes need one to register
# with the cluster, give pods IPs (CNI) and pull images from ECR.

# ---- control-plane IAM role ----------------------------------------------------

data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ---- the cluster ----------------------------------------------------------------

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    # Control-plane ENIs go into private + public subnets so that both
    # internal and internet-facing load balancers can be provisioned.
    subnet_ids              = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_public_access  = true # kubectl from my laptop
    endpoint_private_access = true # nodes talk to the API without leaving the VPC
    public_access_cidrs     = ["0.0.0.0/0"]
  }

  access_config {
    # The IAM identity that runs `terraform apply` becomes cluster-admin, so the
    # very first `kubectl get nodes` works without editing aws-auth by hand.
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  # Explicit: the policy attachment is not referenced by any attribute, but
  # EKS validates the role's permissions at create time and the attachment
  # must be gone *after* the cluster on destroy, not before.
  depends_on = [aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy]

  tags = { Name = var.cluster_name }
}

# ---- worker-node IAM role ------------------------------------------------------

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
}

# The three policies every managed node group needs:
#   WorkerNode  - describe the cluster, register the kubelet
#   CNI         - the aws-node daemonset assigns VPC IPs to pods
#   ECR ReadOnly - lets nodes pull from ECR too (GHCR pulls need no IAM)
resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ---- managed node group --------------------------------------------------------

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name # <- implicit dependency on the cluster
  node_group_name = "${var.cluster_name}-ng"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private[*].id # nodes are never reachable from the internet
  version         = aws_eks_cluster.main.version

  instance_types = var.node_instance_types
  capacity_type  = "ON_DEMAND"
  ami_type       = "AL2023_x86_64_STANDARD"
  disk_size      = 20

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1 # roll nodes one at a time on a version bump
  }

  labels = {
    role = "worker"
  }

  # Same reasoning as the cluster: EKS checks the node role's policies when
  # creating the group, and the attachments must outlive it on destroy.
  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]

  lifecycle {
    # The cluster autoscaler (if installed later) changes desired_size at
    # runtime; Terraform must not fight it on the next apply.
    ignore_changes = [scaling_config[0].desired_size]
  }

  tags = { Name = "${var.cluster_name}-ng" }
}

# ---- add-ons -------------------------------------------------------------------

# vpc-cni and kube-proxy are daemonsets and can be installed before any node
# exists. coredns is a Deployment and stays Pending with no nodes, so the
# add-on creation would time out; hence its depends_on.
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.main]
}

# ---- OIDC provider (IAM Roles for Service Accounts) ---------------------------

# Every EKS cluster has an OIDC issuer. Registering it with IAM lets a
# Kubernetes ServiceAccount assume an IAM role (IRSA) - the AWS load balancer
# controller, external-dns, ExternalSecrets etc. all need this. Without it the
# only way to give a pod AWS permissions is the node role, which is far too wide.
data "tls_certificate" "oidc" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]

  tags = { Name = "${var.cluster_name}-oidc" }
}
