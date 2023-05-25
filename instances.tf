data "aws_ami" "latest_amazon_linux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

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


resource "aws_security_group" "sg-wp" {
  name   = "WebServer Security Group"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.sg-elb.id]
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


resource "aws_instance" "webserver" {
  count = length(aws_subnet.private.*.id)
  ami                    = data.aws_ami.latest_amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id = element(aws_subnet.private.*.id, count.index)
  vpc_security_group_ids = [aws_security_group.sg-wp.id]
  user_data              = file("script.sh")

  tags = {
    Name  = "Web Server Build by Terraform"
    Project = "Terraform Test Project"
  }

  depends_on = [aws_nat_gateway.ngw]
}

resource "aws_elb" "elb" {
  name               = "WebServer-ELB"
  security_groups    = [aws_security_group.sg-elb.id]
  subnets = aws_subnet.private.*.id

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
    name = "WebServer ELB"
    Project = "Terraform Test Project"
  }
}

# Create a new load balancer attachment
resource "aws_elb_attachment" "elb" {
  count = length(aws_instance.webserver.*.id)
  elb      = aws_elb.elb.id
  instance = element(aws_instance.webserver.*.id, count.index)
}