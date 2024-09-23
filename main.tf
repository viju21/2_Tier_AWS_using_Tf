provider "aws" {
  region = "us-east-1"  # Update with your preferred region
}

# Fetch the default VPC
data "aws_vpc" "default" {
  default = true
}

# Fetch all subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# KMS Key for encrypting secrets
resource "aws_kms_key" "rds_kms" {
  description             = "KMS key for encrypting RDS secrets"
  deletion_window_in_days = 10
}

resource "aws_kms_alias" "rds_kms_alias" {
  name          = "alias/rds_secrets"
  target_key_id = aws_kms_key.rds_kms.id
}

# Secrets Manager Secret for RDS credentials
resource "aws_secretsmanager_secret" "my_rds_secret" {
  name        = "rds_postgres_credentials-2118"
  description = "PostgreSQL credentials for RDS instance"
  kms_key_id  = aws_kms_key.rds_kms.id

  tags = {
    Name = "RDSPostgresSecret"
  }
}

resource "aws_secretsmanager_secret_version" "rds_secret_version" {
  secret_id     = aws_secretsmanager_secret.my_rds_secret.id
  secret_string = jsonencode({
    username = "optimus"        # Replace with secure username
    password = "Admin2118"    # Replace with secure password
  })
}

# Security Group for Bastion Host in the Public Subnet
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow SSH access from anywhere"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
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

# Security Group for Web EC2 Instance in the Private Subnet
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow traffic from bastion and RDS"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]  # Allow SSH from Bastion host
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for RDS PostgreSQL
resource "aws_security_group" "rds_sg" {
  name        = "my-privrds-sg"
  description = "Allow PostgreSQL access from web EC2"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]  # Allow from web EC2 instance
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# NAT Gateway for Private Subnet outbound traffic
resource "aws_eip" "nat_eip" {
  # Allocate an Elastic IP (EIP) for NAT Gateway
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = data.aws_subnets.default.ids[0]  # Select first private subnet
}

# Check if an Internet Gateway is already attached to the VPC
data "aws_internet_gateway" "existing_igw" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Internet Gateway for Public Subnet (create only if not exists)
resource "aws_internet_gateway" "igw" {
  count = data.aws_internet_gateway.existing_igw.id == "" ? 1 : 0
  vpc_id = data.aws_vpc.default.id
}

# Route Table for Public Subnet (connects to Internet Gateway)
resource "aws_route_table" "public_rt" {
  vpc_id = data.aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.existing_igw.id != "" ? data.aws_internet_gateway.existing_igw.id : aws_internet_gateway.igw[0].id
  }
}

# Associate Public Route Table with Public Subnet
resource "aws_route_table_association" "public_association" {
  subnet_id      = data.aws_subnets.default.ids[0]  # Select first public subnet
  route_table_id = aws_route_table.public_rt.id
}

# Route Table for Private Subnet (connects to NAT Gateway)
resource "aws_route_table" "private_rt" {
  vpc_id = data.aws_vpc.default.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

# Associate Private Route Table with Private Subnets
resource "aws_route_table_association" "private_association_a" {
  subnet_id      = data.aws_subnets.default.ids[1]  # Select first private subnet
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_association_b" {
  subnet_id      = data.aws_subnets.default.ids[2]  # Select second private subnet
  route_table_id = aws_route_table.private_rt.id
}

# Web EC2 instance in the private subnet
resource "aws_instance" "web_server" {
  ami           = "ami-0e86e20dae9224db8"  # Update with the latest AMI ID
  instance_type = "t2.micro"
  key_name      = "tf_key"
  subnet_id     = data.aws_subnets.default.ids[1]  # Select first private subnet
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name = "Web-Instance"
  }
}

# Bastion Host EC2 instance in the public subnet
resource "aws_instance" "bastion" {
  ami           = "ami-0e86e20dae9224db8"  # Update with the latest AMI ID
  instance_type = "t2.micro"
  key_name      = "tf_key"
  subnet_id     = data.aws_subnets.default.ids[0]  # Select first public subnet
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  tags = {
    Name = "Bastion-Host"
  }
}

# RDS PostgreSQL instance
resource "aws_db_instance" "postgres" {
  allocated_storage       = 20
  instance_class          = "db.t3.micro"
  engine                  = "postgres"
  engine_version          = "15"  # Update to a valid version
  db_subnet_group_name    = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  username                = jsondecode(aws_secretsmanager_secret_version.rds_secret_version.secret_string)["username"]
  password                = jsondecode(aws_secretsmanager_secret_version.rds_secret_version.secret_string)["password"]
  publicly_accessible     = false
  skip_final_snapshot     = true
  multi_az                = true  # Enable Multi-AZ deployment
  backup_retention_period = 7     # Enable automated daily backups (7 days retention)
  storage_encrypted       = true  # Enable encryption at rest


  tags = {
    Name = "Postgres-RDS"
  }
}


# RDS Subnet Group covering at least 2 AZs
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = [
    data.aws_subnets.default.ids[1],  # Subnet ID from AZ A
    data.aws_subnets.default.ids[2],  # Subnet ID from AZ B
    # Add more subnet IDs from additional AZs as needed
  ]

  tags = {
    Name = "RDS Subnet Group"
  }
}
