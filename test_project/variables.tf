variable "region" {
  default     = "eu-central-1"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "asg_min_size" {
  default = 2
}

variable "asg_max_size" {
  default = 6
}

variable "pass_length" {
  default = 12
}

variable "http_port" {
  default = 80
}