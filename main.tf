terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure AWS provider
provider "aws" {
  region = "us-east-1"
  shared_credentials_file = "/Users/johnbutler/.aws/credentials"
  profile = "cloud_guru"
}

# Available AZs
data "aws_availability_zones" "available" {
}

################################################################################
# VPC Module
################################################################################

# Create a VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name="my-vpc"
  cidr = "10.0.0.0/16"

  azs = data.aws_availability_zones.available.names
  public_subnets = ["10.0.0.0/24"]
  # elasticache_subnets = ["10.0.5.0/24", "10.0.6.0/24"]


  enable_dns_support = true
  enable_dns_hostnames = true
  create_database_subnet_group = true
  create_database_subnet_route_table = true
  create_database_internet_gateway_route = true
}

# resource "aws_subnet" "rds_subnet_group_2" {
#   vpc_id = module.vpc.vpc_id
#   cidr_block = "10.0.1.0/24"
# }


# # RDS Subnet Group
# resource "aws_db_subnet_group" "rds_subnet_group" {
#   name = "db_subnet_group"
#   subnet_ids = [aws_subnet.rds_subnet_group_1.id, aws_subnet.rds_subnet_group_2.id]
# }

################################################################################
# RDS
################################################################################

# RDS Security Group
resource "aws_security_group" "rds-security-group" {
  name = "rds-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS Subnets
resource "aws_subnet" "rds_subnet_group_1" {
  vpc_id = module.vpc.vpc_id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}
resource "aws_subnet" "rds_subnet_group_2" {
  vpc_id = module.vpc.vpc_id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

# RDS Subnets
resource "aws_db_subnet_group" "rds_subnet" {
  name       = "rds_subnet"
  subnet_ids = [aws_subnet.rds_subnet_group_1.id, aws_subnet.rds_subnet_group_2.id]
}


# RDS Instance
resource "aws_db_instance" "my-db" {
  allocated_storage    = 5
  engine               = "postgres"
  engine_version       = "12.7"
  instance_class       = "db.t2.micro"
  name                 = "postgres"
  username             = "postgres"
  password             = "postgres"
  db_subnet_group_name = aws_db_subnet_group.rds_subnet.id
  vpc_security_group_ids = [aws_security_group.rds-security-group.id]
  skip_final_snapshot  = true
  publicly_accessible = true
}

################################################################################
# EC2
################################################################################

# EC2 Security Group
resource "aws_security_group" "ec2-security-group" {
  name = "ec2-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}


# EC2 Subnet Group
resource "aws_subnet" "ec2_subnet_group" {
  vpc_id = module.vpc.vpc_id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1a"
}

# Key Pair Algorithm
resource "tls_private_key" "this" {
  algorithm = "RSA"
}

# Create EC2 Key Pair
module "key_pair" {
  source = "terraform-aws-modules/key-pair/aws"

  key_name   = "demo"
  public_key = tls_private_key.this.public_key_openssh
}


# EC2 Instance with User Data
resource "aws_instance" "ec2-instance" {
  ami = "ami-0dc2d3e4c0f9ebd18"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.ec2_subnet_group.id
  vpc_security_group_ids =  [aws_security_group.ec2-security-group.id]
  user_data = "${file("user-data.sh")}"
  key_name = module.key_pair.key_pair_key_name
  # associate_public_ip_address = true
}

# Elastic IP
resource "aws_eip" "my-eip" {
  instance = aws_instance.ec2-instance.id
  vpc = true
}

# # Internet Gateway
# resource "aws_internet_gateway" "my-ig" {
#   vpc_id = module.vpc.vpc_id
# }

# Route Table
resource "aws_route_table" "my-route-table" {
  vpc_id = module.vpc.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = module.vpc.igw_id
  }
}

# Route Table Association
resource "aws_route_table_association" "my-route-table-association" {
  subnet_id = aws_subnet.ec2_subnet_group.id
  route_table_id = aws_route_table.my-route-table.id
}

################################################################################
# Redis
################################################################################

# Redis
resource "aws_elasticache_cluster" "redis-cache" {
  cluster_id = "redis-cache"
  engine = "redis"
  node_type = "cache.t2.micro"
  num_cache_nodes = 1
  parameter_group_name = "default.redis6.x"
  engine_version = "6.x"
  port = 6379
  security_group_ids = [aws_security_group.redis-security-group.id]
  subnet_group_name = aws_elasticache_subnet_group.redis-subnet-group.name
}


# Redis Subnet Group
resource "aws_subnet" "redis_subnet" {
  vpc_id = module.vpc.vpc_id
  cidr_block = "10.0.4.0/24"
}

resource "aws_elasticache_subnet_group" "redis-subnet-group" {
  name = "redis-subnet-group"
  subnet_ids = [aws_subnet.redis_subnet.id]
}

# resource "aws_subnet" "redis_subnet_2" {
#   vpc_id = module.vpc.vpc_id
#   cidr_block = "10.0.5.0/24"
# }

# Redis Security Group
resource "aws_security_group" "redis-security-group" {
  name = "redis-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port = 6379
    to_port = 6379
    protocol = "tcp"
    security_groups = [aws_security_group.ec2-security-group.id]
  }
}

# Get my IP address by using the http data source, which runs a get request
data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}
