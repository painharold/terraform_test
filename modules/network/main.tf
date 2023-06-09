#----------------------------------------------------------
# Terraform Test Project
# Network Module
#  - VPC
#  - Internet Gateway
#  - Public Subnets
#  - Private Subnets
#  - NAT Gateways
#----------------------------------------------------------

data "aws_availability_zones" "zones" {}

#Create VPC
resource "aws_vpc" "my_vpc" {
  cidr_block       = var.vpc_cidr

  tags = {
    Name = "My VPC"
    Project = "Terraform Test Project"
  }
}

#Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "Internet Gateway"
    Project = "Terraform Test Project"
  }
}

#-------------Public Subnets and Routing----------------------------------------

#Create Public Subnets
resource "aws_subnet" "public" {
  count = length(data.aws_availability_zones.zones.names)
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.zones.names[count.index]

  tags = {
    Name = "Public Subnet"
    Project = "Terraform Test Project"
  }
}

#Create Public Route Table
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

#Create Public Route Table Association
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public.*.id)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = element(aws_route_table.public.*.id, count.index)
}

#-----NAT Gateways with Elastic IPs--------------------------

#Create Elastic IP
resource "aws_eip" "main" {
  count = length(data.aws_availability_zones.zones.names)
  domain   = "vpc"

  tags = {
    Name = "Elastic IP For NAT"
    Project = "Terraform Test Project"
  }
}

#Create NAT Gateways
resource "aws_nat_gateway" "ngw" {
  count = length(data.aws_availability_zones.zones.names)
  allocation_id = element(aws_eip.main.*.id, count.index)
  subnet_id     = element(aws_subnet.public.*.id, count.index)

  tags = {
    Name = "NAT Gateway"
    Project = "Terraform Test Project"
  }
}

#-------------Private Subnets and Routing----------------------------------------

#Create Private Subnets
resource "aws_subnet" "private" {
  count = length(data.aws_availability_zones.zones.names)
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = cidrsubnet(var.vpc_cidr, 8, 20 + count.index)
  availability_zone = data.aws_availability_zones.zones.names[count.index]

  tags = {
    Name = "Private Subnet"
    Project = "Terraform Test Project"
  }
}

#Create Private Route Table
resource "aws_route_table" "private" {
  count = length(data.aws_availability_zones.zones.names)
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = element(aws_nat_gateway.ngw.*.id, count.index)
  }

  tags = {
    Name = "Private Subnet Route Table"
    Project = "Terraform Test Project"
  }
}

#Create Private Route Table Association
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private.*.id)
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}