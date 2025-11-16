locals {
  prefix = "${var.project_name}-${var.environment}"

  # Common tags
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }

  # Resource names
  vpc_name              = "${local.prefix}-vpc"
  igw_name              = "${local.prefix}-igw"
  nat_name              = "${local.prefix}-nat"
  alb_name              = "${local.prefix}-alb"
  alb_sg_name           = "${local.prefix}-alb-sg"
  bastion_sg_name       = "${local.prefix}-bastion-sg"
  api_sg_name           = "${local.prefix}-api-sg"
  ec2_role_name         = "${local.prefix}-ec2-role"
  ec2_profile_name      = "${local.prefix}-ec2-profile"
  key_name              = "${local.prefix}-key"
  bastion_instance_name = "${local.prefix}-bastion"
  v1_api_1_name         = "${local.prefix}-v1-api-1"
  v1_api_2_name         = "${local.prefix}-v1-api-2"
  v1_tg_name            = "${local.prefix}-v1-tg"
  api_gateway_name      = "${local.prefix}-api"
  prod_stage_name       = "${local.prefix}-prod-stage"
}
