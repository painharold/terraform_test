#----------------------------------------------------------
# Terraform Test Project
#  - Security Group For Load Balancer
#  - Security Group For Web Servers
#  - Security Group For Data Base
#----------------------------------------------------------

# Create a security group for load balancer
resource "aws_security_group" "sg-lb" {
  name   = "ELB Security Group"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "Security Group ALB"
    Project = "Terraform Test Project"
  }
}

# Create a security group for web servers
resource "aws_security_group" "sg-wp" {
  name   = "WebServer Security Group"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.sg-lb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "Security Group WEB"
    Project = "Terraform Test Project"
  }
}

# Create a security group for data base
resource "aws_security_group" "sg-db" {
  name   = "DB Security Group"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.sg-wp.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "Security Group DB"
    Project = "Terraform Test Project"
  }
}
