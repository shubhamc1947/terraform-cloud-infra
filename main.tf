#################################
# Provider setup
#################################

#################################
# Networking: VPC and Subnets
#################################
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Name = local.vpc_name })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, { Name = local.igw_name })
}

resource "aws_subnet" "public" {
  for_each = toset(var.public_subnets)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = "${var.aws_region}${element(["a", "b"], index(var.public_subnets, each.value))}"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-public-${index(var.public_subnets, each.value) + 1}"
  })
}

resource "aws_subnet" "private" {
  for_each = toset(var.private_subnets)

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = "${var.aws_region}${element(["a", "b"], index(var.private_subnets, each.value))}"

  tags = merge(local.common_tags, {
    Name = "${local.prefix}-private-${index(var.private_subnets, each.value) + 1}"
  })
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(local.common_tags, { Name = "${local.nat_name}-eip" })
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = element(values(aws_subnet.public), 0).id

  tags       = merge(local.common_tags, { Name = local.nat_name })
  depends_on = [aws_internet_gateway.main]
}

#################################
# Route Tables
#################################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, { Name = "${local.prefix}-public-rt" })
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(local.common_tags, { Name = "${local.prefix}-private-rt" })
}

resource "aws_route_table_association" "private_assoc" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

#################################
# Security Groups
#################################
resource "aws_security_group" "alb" {
  name        = local.alb_sg_name
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = local.alb_sg_name })
}

resource "aws_security_group" "bastion" {
  name        = local.bastion_sg_name
  description = "Security group for Bastion host"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = local.bastion_sg_name })
}

resource "aws_security_group" "api" {
  name        = local.api_sg_name
  description = "Security group for API instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = var.api_port
    to_port         = var.api_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = local.api_sg_name })
}

#################################
# IAM and Existing SSH Key
#################################
resource "aws_iam_role" "ec2_role" {
  name = local.ec2_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = local.ec2_profile_name
  role = aws_iam_role.ec2_role.name
}

# resource "aws_key_pair" "main" {
#   key_name   = local.key_name
#   public_key = file(var.ssh_public_key_path)
#   tags       = merge(local.common_tags, { Name = local.key_name })
# }

#################################
# Use Existing SSH Key (tarmac.pem)
#################################
data "aws_key_pair" "existing" {
  key_name = "tarmac" # 👈 must match the key name in AWS EC2 console
}


#################################
# EC2 Instances
#################################
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = element(values(aws_subnet.public), 0).id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name               = data.aws_key_pair.existing.key_name
  tags                   = merge(local.common_tags, { Name = local.bastion_instance_name })
}

resource "aws_instance" "v1_api_1" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = element(values(aws_subnet.private), 0).id
  vpc_security_group_ids = [aws_security_group.api.id]
  key_name               = data.aws_key_pair.existing.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  user_data              = file("${path.module}/scripts/api-userdata.sh")
  tags                   = merge(local.common_tags, { Name = local.v1_api_1_name })
}

resource "aws_instance" "v1_api_2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = element(values(aws_subnet.private), 1).id
  vpc_security_group_ids = [aws_security_group.api.id]
  key_name               = data.aws_key_pair.existing.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  user_data              = file("${path.module}/scripts/api-userdata.sh")
  tags                   = merge(local.common_tags, { Name = local.v1_api_2_name })
}

#################################
# ALB + API Gateway
#################################
resource "aws_lb" "main" {
  name               = local.alb_name
  internal           = false
  load_balancer_type = "application"
  subnets            = [for s in aws_subnet.public : s.id]
  security_groups    = [aws_security_group.alb.id]
  tags               = merge(local.common_tags, { Name = local.alb_name })
}

resource "aws_lb_target_group" "v1" {
  name     = local.v1_tg_name
  port     = var.api_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }

  tags = merge(local.common_tags, { Name = local.v1_tg_name })
}

resource "aws_lb_target_group_attachment" "v1_1" {
  target_group_arn = aws_lb_target_group.v1.arn
  target_id        = aws_instance.v1_api_1.id
  port             = var.api_port
}

resource "aws_lb_target_group_attachment" "v1_2" {
  target_group_arn = aws_lb_target_group.v1.arn
  target_id        = aws_instance.v1_api_2.id
  port             = var.api_port
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.v1.arn
  }
}

resource "aws_apigatewayv2_api" "main" {
  name          = local.api_gateway_name
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "alb" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = "http://${aws_lb.main.dns_name}"
  integration_method = "ANY"
  connection_type    = "INTERNET"
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "prod"
  auto_deploy = true
}
