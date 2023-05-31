# Get latest ami of Amazon Linux
data "aws_ami" "latest_amazon_linux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}


resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

## Create a key pair using above private key
resource "aws_key_pair" "keypair" {

  # Name of the Key
  key_name = "keypair"

  public_key = tls_private_key.private_key.public_key_openssh
  depends_on = [tls_private_key.private_key]
}

## Save the private key at the specified path
resource "local_file" "save-key" {
  content  = tls_private_key.private_key.private_key_pem
  filename = "./pub_keypair.pem"
}



#-------------Security Groups----------------------------------------

# Create a security group for load balancer
resource "aws_security_group" "sg-elb" {
  name   = "ELB Security Group"
  vpc_id = aws_vpc.my_vpc.id

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
    Name = "Security Group ELB"
    Project = "Terraform Test Project"
  }
}

# Create a security group for web servers
resource "aws_security_group" "sg-wp" {
  name   = "WebServer Security Group"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.sg-elb.id, aws_security_group.sg-bh.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.sg-bh.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Security Group WEB"
    Project = "Terraform Test Project"
  }
}

# Create a security group for db
resource "aws_security_group" "sg-db" {
  name   = "DB Security Group"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.sg-wp.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Security Group DB"
    Project = "Terraform Test Project"
  }
}

#-------------Instances----------------------------------------

# Create webservers
resource "aws_instance" "webserver" {
  count = length(aws_subnet.private.*.id)
  ami                    = data.aws_ami.latest_amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id = element(aws_subnet.private.*.id, count.index)
  vpc_security_group_ids = [aws_security_group.sg-wp.id]
  key_name = "keypair"
  user_data = templatefile("script.sh.tpl", {
    db_name = aws_db_instance.db-mysql.db_name,
    db_user = aws_db_instance.db-mysql.username,
    db_password = data.aws_ssm_parameter.my_rds_password.value
    db_hostname = aws_db_instance.db-mysql.endpoint
  })

  tags = {
    Name  = "Web Server"
    Project = "Terraform Test Project"
  }

  depends_on = [aws_nat_gateway.ngw, aws_db_instance.db-mysql]
}

#-------------Load Balancer----------------------------------------

# Create a new load balancer
resource "aws_elb" "elb" {
  name               = "WebServer-ELB"
  security_groups    = [aws_security_group.sg-elb.id]
  subnets = aws_subnet.public.*.id

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  health_check {
    healthy_threshold   = 2
    interval            = 10
    target              = "HTTP:80/"
    timeout             = 3
    unhealthy_threshold = 2
  }
  tags = {
    name = "ELB"
    Project = "Terraform Test Project"
  }
}

# Create a new load balancer attachment
resource "aws_elb_attachment" "elb" {
  count = length(aws_instance.webserver.*.id)
  elb      = aws_elb.elb.id
  instance = element(aws_instance.webserver.*.id, count.index)
}

#-------------Data Base----------------------------------------

resource "random_string" "rds_password" {
  length = 12
  special = true
  override_special = "!#$&"
}

resource "aws_ssm_parameter" "rds_password" {
  name  = "/test_project/mysql"
  type  = "SecureString"
  value = random_string.rds_password.result
  description = "Master Password for RDS MySQL"
}

data "aws_ssm_parameter" "my_rds_password" {
  name = "/test_project/mysql"
  depends_on = [aws_ssm_parameter.rds_password]
}

resource "aws_db_subnet_group" "db_subnets" {
  name       = "main"
  subnet_ids = aws_subnet.private.*.id

  tags = {
    name = "DB Subnet Group"
    Project = "Terraform Test Project"
  }
}

resource "aws_db_instance" "db-mysql" {
  identifier = "test-project-rds"
  allocated_storage = 20
  storage_type = "gp2"
  engine = "mysql"
  engine_version = "5.7"
  instance_class = "db.t2.micro"
  db_name = "wp_db"
  db_subnet_group_name = aws_db_subnet_group.db_subnets.id
  vpc_security_group_ids = [aws_security_group.sg-db.id]
  username = "administrator"
  password = data.aws_ssm_parameter.my_rds_password.value
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot = true
  apply_immediately = true
  tags = {
    name = "DB Subnet Group"
    Project = "Terraform Test Project"
  }
}





# Create a security group for bastion
resource "aws_security_group" "sg-bh" {
  name   = "BH Security Group"
  vpc_id = aws_vpc.my_vpc.id

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

  tags = {
    Name = "Security Group DB"
    Project = "Terraform Test Project"
  }
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.latest_amazon_linux.id
  instance_type          = "t3.nano"
  subnet_id = aws_subnet.public.*[0].id
  vpc_security_group_ids = [aws_security_group.sg-bh.id]
  key_name = "keypair"

  tags = {
    Name  = "Bastion Host"
    Project = "Terraform Test Project"
  }

  depends_on = [aws_nat_gateway.ngw]
}