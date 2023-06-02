output "vpc_id" {
  value = aws_vpc.my_vpc.id
}

output "vpc_cidr" {
  value = aws_vpc.my_vpc.cidr_block
}

output "public_subnets_id" {
  value = aws_subnet.public.*.id
}

output "private_subnets_id" {
  value = aws_subnet.private.*.id
}