
provider "aws" {
  alias  = "west2"
  region = "us-west-2"
}

data "aws_ami" "amazon_linux_w2" {
  provider    = aws.west2
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_key_pair" "elk" {
  provider   = aws.west2
  key_name   = "final-project-key"
  public_key = file(pathexpand("~/.ssh/final_project.pub"))
}
resource "aws_vpc" "elk" {
  provider             = aws.west2
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "final-project-elk-vpc"
  }
}

resource "aws_internet_gateway" "elk" {
  provider = aws.west2
  vpc_id   = aws_vpc.elk.id

  tags = {
    Name = "final-project-elk-igw"
  }
}

resource "aws_subnet" "elk" {
  provider                = aws.west2
  vpc_id                  = aws_vpc.elk.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "final-project-elk-subnet"
  }
}

resource "aws_route_table" "elk" {
  provider = aws.west2
  vpc_id   = aws_vpc.elk.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.elk.id
  }
}

resource "aws_route_table_association" "elk" {
  provider       = aws.west2
  subnet_id      = aws_subnet.elk.id
  route_table_id = aws_route_table.elk.id
}

resource "aws_security_group" "elk" {
  provider    = aws.west2
  name        = "final-project-elk"
  description = "Elasticsearch + Kibana (cross-region: vCPU quota workaround)"
  vpc_id      = aws_vpc.elk.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Elasticsearch (Filebeat from EKS nodes)"
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kibana UI"
    from_port   = 5601
    to_port     = 5601
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "elk" {
  provider               = aws.west2
  ami                    = data.aws_ami.amazon_linux_w2.id
  instance_type          = "t3.medium"
  key_name               = aws_key_pair.elk.key_name
  vpc_security_group_ids = [aws_security_group.elk.id]
  subnet_id              = aws_subnet.elk.id

  tags = {
    Name      = "final-project-elk"
    Project   = "final-project"
    ManagedBy = "terraform"
  }
}

output "elk_public_ip" {
  value = aws_instance.elk.public_ip
}

output "elk_private_ip" {
  value = aws_instance.elk.private_ip
}