#----------------------------------------------------------
# Terraform Test Project
#  - Application Load Balancer
#  - Load Balancer Target Group
#  - Load Balancer Listener
#----------------------------------------------------------

# Create Application Load Balancer
resource "aws_lb" "web" {
  name               = "WebServer-ALB"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg-lb.id]
  subnets            = module.vpc.public_subnets_id

  tags = {
    name    = "ALB"
    Project = "Terraform Test Project"
  }
}

# Create Load Balancer Target Group
resource "aws_lb_target_group" "web" {
  name        = "WebServer-TG"
  vpc_id      = module.vpc.vpc_id
  port        = var.http_port
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

# Create Load Balancer Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = var.http_port
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