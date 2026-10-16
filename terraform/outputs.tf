# ---- network ----
output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (NAT Gateway, internet-facing load balancers)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (EKS worker nodes)."
  value       = aws_subnet.private[*].id
}

output "nat_gateway_public_ip" {
  description = "Public IP all outbound traffic from the nodes appears to come from (whitelist this on external services)."
  value       = aws_eip.nat.public_ip
}

# ---- eks ----
output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "HTTPS endpoint of the Kubernetes API server."
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority" {
  description = "Base64-encoded CA certificate of the API server (goes into kubeconfig)."
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL; needed in IRSA trust policies."
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for this cluster (IRSA)."
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "node_group_name" {
  description = "Name of the managed node group."
  value       = aws_eks_node_group.main.node_group_name
}

output "node_role_arn" {
  description = "IAM role the worker nodes run with."
  value       = aws_iam_role.node.arn
}

# ---- how to connect ----
output "update_kubeconfig_command" {
  description = "Run this once after apply; then kubectl and helm talk to the new cluster."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name} --alias ${aws_eks_cluster.main.name}"
}

output "target" {
  description = "Where this state was applied."
  value       = var.use_localstack ? "localstack (${var.localstack_endpoint})" : "aws (${var.aws_region})"
}
