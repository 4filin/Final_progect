# EKS требует явных подсетей. Наш EC2 живёт в default VPC — используем её подсети
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}


module "eks" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-eks.git?ref=v20.37.0"


  cluster_name    = "final-project"
  cluster_version = "1.35"

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids

  cluster_endpoint_public_access = true   # для демо; в проде — private + bastion

  # Автоматически дать создателю (твоему AWS-пользователю) админ-доступ к кластеру
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.small"]   # t3.micro мал для k8s-подов; t3.small ~$0.023/час
      min_size       = 1
      max_size       = 3              # потолок для масштабирования
      desired_size   = 2              # 2 реплики нод = отказоустойчивость
    }
  }
}

# kubectl изнутри VPC (dev-инстанс, будущие CI-агенты в VPC)
resource "aws_security_group_rule" "cluster_ingress_vpc" {
  description       = "Allow HTTPS to cluster API from within VPC"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = module.eks.cluster_security_group_id
  cidr_blocks       = [data.aws_vpc.default.cidr_block]
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

