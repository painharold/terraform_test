#----------------------------------------------------------
# Terraform Test Project
#  - Password
#  - Data Base Subnet Group
#  - Data Base
#----------------------------------------------------------

# Generate Password
resource "random_string" "rds_password" {
  length           = var.pass_length
  special          = false
}

# Create Password in AWS
resource "aws_ssm_parameter" "rds_password" {
  name        = "/test_project/mysql"
  type        = "SecureString"
  value       = random_string.rds_password.result
  description = "Master Password for RDS MySQL"
}

data "aws_ssm_parameter" "my_rds_password" {
  name       = "/test_project/mysql"
  depends_on = [aws_ssm_parameter.rds_password]
}

# Create Data Base Subnet Group
resource "aws_db_subnet_group" "db_subnets" {
  name       = "main"
  subnet_ids = module.vpc.private_subnets_id

  tags = {
    name    = "DB Subnet Group"
    Project = "Terraform Test Project"
  }
}

# Create Data Base
resource "aws_db_instance" "db-mysql" {
  identifier             = "test-project-rds"
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  db_name                = "wp_db"
  db_subnet_group_name   = aws_db_subnet_group.db_subnets.id
  vpc_security_group_ids = [aws_security_group.sg-db.id]
  username               = "administrator"
  password               = data.aws_ssm_parameter.my_rds_password.value
  parameter_group_name   = "default.mysql5.7"
  skip_final_snapshot    = true
  apply_immediately      = true

  tags                   = {
    name    = "DB Subnet Group"
    Project = "Terraform Test Project"
  }
}