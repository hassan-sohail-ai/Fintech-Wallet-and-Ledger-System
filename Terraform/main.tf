terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# 1. VPC Definition (Yeh sab se pehle hona zaroori hai)
resource "aws_vpc" "fintech_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "fintech-wallet-vpc"
  }
}

# 2. ECR Repository
resource "aws_ecr_repository" "fintech_ecr" {
  name                 = "fintech-wallet-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# 3. Public Subnet 1
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.fintech_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "fintech-public-subnet-1"
  }
}

# 4. Public Subnet 2
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.fintech_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"

  tags = {
    Name = "fintech-public-subnet-2"
  }
}

# 5. Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.fintech_vpc.id

  tags = {
    Name = "fintech-igw"
  }
}

# 6. Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.fintech_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "fintech-public-rt"
  }
}

# 7. Route Table Associations
resource "aws_route_table_association" "a1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "a2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

# 8. IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "fintech-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# 9. EKS Cluster
resource "aws_eks_cluster" "fintech_eks" {
  name     = "fintech-wallet-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.public_1.id,
      aws_subnet.public_2.id
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_route_table_association.a1,
    aws_route_table_association.a2
  ]
}

# 1. IAM Role for EKS Worker Nodes
resource "aws_iam_role" "eks_nodes_role" {
  name = "fintech-eks-nodes-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "nodes_amazon_eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes_role.name
}

resource "aws_iam_role_policy_attachment" "nodes_amazon_eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes_role.name
}

resource "aws_iam_role_policy_attachment" "nodes_amazon_ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes_role.name
}

# 2. EKS Node Group (Worker Nodes)
resource "aws_eks_node_group" "fintech_node_group" {
  cluster_name    = aws_eks_cluster.fintech_eks.name
  node_group_name = "fintech-node-group"
  node_role_arn   = aws_iam_role.eks_nodes_role.arn
  subnet_ids      = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.small"]

  depends_on = [
    aws_iam_role_policy_attachment.nodes_amazon_eks_worker_node_policy,
    aws_iam_role_policy_attachment.nodes_amazon_eks_cni_policy,
    aws_iam_role_policy_attachment.nodes_amazon_ec2_container_registry_read_only,
  ]
}