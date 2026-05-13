variable "create_eks"         { type = bool }
variable "project_name"       { type = string }
variable "subnet_ids"         { type = list(string) }
variable "node_instance_type" { type = string }
variable "eks_version"        { type = string }

resource "aws_iam_role" "cluster" {
  count = var.create_eks ? 1 : 0
  name  = "${var.project_name}-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow",
      Principal = { Service = "eks.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  count      = var.create_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster[0].name
}

resource "aws_eks_cluster" "main" {
  count    = var.create_eks ? 1 : 0
  name     = "${var.project_name}-cluster"
  role_arn = aws_iam_role.cluster[0].arn
  version  = var.eks_version
  vpc_config { subnet_ids = var.subnet_ids }
  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

resource "aws_iam_role" "node" {
  count = var.create_eks ? 1 : 0
  name  = "${var.project_name}-eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "node_policies" {
  for_each = var.create_eks ? toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ]) : toset([])
  policy_arn = each.value
  role       = aws_iam_role.node[0].name
}

resource "aws_eks_node_group" "main" {
  count           = var.create_eks ? 1 : 0
  cluster_name    = aws_eks_cluster.main[0].name
  node_group_name = "${var.project_name}-nodes"
  node_role_arn   = aws_iam_role.node[0].arn
  subnet_ids      = var.subnet_ids
  instance_types  = [var.node_instance_type]
  scaling_config  { desired_size = 1; min_size = 1; max_size = 2 }
  depends_on      = [aws_iam_role_policy_attachment.node_policies]
}

output "cluster_name" {
  value = var.create_eks ? aws_eks_cluster.main[0].name : "eks-not-created"
}
output "cluster_endpoint" {
  value = var.create_eks ? aws_eks_cluster.main[0].endpoint : "eks-not-created"
}
