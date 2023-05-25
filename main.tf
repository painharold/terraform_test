#----------------------------------------------------------
# Terraform Test Project
#  - VPC
#  - Internet Gateway
#  - Public Subnets
#  - Private Subnets
#  - NAT Gateways
#----------------------------------------------------------

provider "aws" {
  region = "eu-central-1"
}

#Creating VPC
resource "aws_vpc" "my_vpc" {
  cidr_block       = "10.0.0.0/16"

  tags = {
    Name = "My VPC"
    Project = "Terraform Test Project"
  }
}

#Creating Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "Internet Gateway"
    Project = "Terraform Test Project"
  }
}

#-------------Public Subnets and Routing----------------------------------------

#Creating Public Subnets
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet"
    Project = "Terraform Test Project"
  }
}

#Creating Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Public Subnet Route Table"
    Project = "Terraform Test Project"
  }
}

#Creating Public Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

#-----NAT Gateways with Elastic IPs--------------------------

#Creating Elastic IP
resource "aws_eip" "main" {
  vpc      = true

  tags = {
    Name = "Elastic IP For NAT"
    Project = "Terraform Test Project"
  }
}

#Creating NAT Gateways
resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.main.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "NAT Gateway"
    Project = "Terraform Test Project"
  }
}

#-------------Private Subnets and Routing----------------------------------------

#Creating Private Subnets
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "Private Subnet"
    Project = "Terraform Test Project"
  }
}

#Creating Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = "Private Subnet Route Table"
    Project = "Terraform Test Project"
  }
}

#Creating Private Route Table Association
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

output "vpc_id" {
  value = aws_vpc.my_vpc.id
}

output "vpc_cidr" {
  value = aws_vpc.my_vpc.cidr_block
}

output "public_subnets_id" {
  value = aws_subnet.public[*].id
}