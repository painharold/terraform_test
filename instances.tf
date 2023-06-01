# Get latest ami of Amazon Linux
data "aws_ami" "latest_amazon_linux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

#-------------Security Groups----------------------------------------

# Create a security group for load balancer
resource "aws_security_group" "sg-lb" {
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
    Name    = "Security Group ALB"
    Project = "Terraform Test Project"
  }
}

# Create a security group for web servers
resource "aws_security_group" "sg-wp" {
  name   = "WebServer Security Group"
  vpc_id = aws_vpc.my_vpc.id

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

# Create a security group for db
resource "aws_security_group" "sg-db" {
  name   = "DB Security Group"
  vpc_id = aws_vpc.my_vpc.id

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

#-------------Instances----------------------------------------

# Create webservers
resource "aws_instance" "webserver" {
  count                  = length(aws_subnet.private.*.id)
  ami                    = data.aws_ami.latest_amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = element(aws_subnet.private.*.id, count.index)
  vpc_security_group_ids = [aws_security_group.sg-wp.id]
  user_data              = templatefile("script.sh.tpl", {
    db_name     = aws_db_instance.db-mysql.db_name,
    db_user     = aws_db_instance.db-mysql.username,
    db_password = data.aws_ssm_parameter.my_rds_password.value
    db_hostname = aws_db_instance.db-mysql.endpoint
  })

  tags = {
    Name    = "Web Server"
    Project = "Terraform Test Project"
  }

  depends_on = [aws_db_instance.db-mysql]
}

#-------------Load Balancer----------------------------------------

resource "aws_lb" "web" {
  name               = "WebServer-ALB"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg-lb.id]
  subnets            = aws_subnet.public.*.id

  tags = {
    name    = "ALB"
    Project = "Terraform Test Project"
  }
}

resource "aws_lb_target_group" "web" {
  name        = "WebServer-TG"
  vpc_id      = aws_vpc.my_vpc.id
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"

  health_check {
    interval            = 5
    path                = "/"
    protocol            = "HTTP"
    timeout             = 2
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher = "200-399"
  }

  tags = {
    name    = "ALB Target Group"
    Project = "Terraform Test Project"
  }
}

# Load Balancer Target Group attachment
resource "aws_lb_target_group_attachment" "alb_attachments" {
  count            = length(aws_instance.webserver.*.id)
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = element(aws_instance.webserver.*.id, count.index)
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  tags = {
    name    = "ALB Listener"
    Project = "Terraform Test Project"
  }
}

#-------------Data Base----------------------------------------

resource "random_string" "rds_password" {
  length           = 12
  special          = true
  override_special = "!#$&@"
}

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

resource "aws_db_subnet_group" "db_subnets" {
  name       = "main"
  subnet_ids = aws_subnet.private.*.id

  tags = {
    name    = "DB Subnet Group"
    Project = "Terraform Test Project"
  }
}

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