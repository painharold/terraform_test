#----------------------------------------------------------
# Terraform Test Project
# Wordpress WebServer with Autoscaling
#----------------------------------------------------------

provider "aws" {
  region = var.region
}

module "vpc" {
  source = "../modules/network"
}

# Create Launch Template
resource "aws_launch_template" "web" {
  name                   = "WP-WebServer"
  image_id               = data.aws_ami.latest_amazon_linux.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.sg-wp.id]
  user_data              = base64encode(templatefile("script.sh.tpl", {
        db_name     = aws_db_instance.db-mysql.db_name,
        db_user     = aws_db_instance.db-mysql.username,
        db_password = data.aws_ssm_parameter.my_rds_password.value
        db_hostname = aws_db_instance.db-mysql.endpoint
      }))

  depends_on = [aws_db_instance.db-mysql]
}

# Create Autoscaling Group
resource "aws_autoscaling_group" "web" {
  name                = "WebServer-ASG-Ver-${aws_launch_template.web.latest_version}"
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = length(module.vpc.aws_availability_zones)
  min_elb_capacity    = 2
  health_check_type   = "ELB"
  vpc_zone_identifier = module.vpc.public_subnets_id
  target_group_arns   = [aws_lb_target_group.web.arn]

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  dynamic "tag" {
    for_each = {
      Name   = "WebServer in ASG-v${aws_launch_template.web.latest_version}"
      Project = "Terraform Test Project"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}