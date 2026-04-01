# Latest Ubuntu AMI from Canonical
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

# -------------------------
# NETWORK - NEW VPC
# -------------------------
check "public_private_az_count" {
  assert {
    condition = (
      length(var.public_subnet_cidrs) == length(var.availability_zones) &&
      length(var.private_subnet_cidrs) == length(var.availability_zones)
    )
    error_message = "Each public and private subnet is mapped to availability_zones[index]: all three lists must have the same length."
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"

  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"

  }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${count.index + 1}"

  }
}


resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-private-${count.index + 1}"

  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"

  }
}

resource "aws_route_table_association" "public_assoc" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"

  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.project_name}-nat"

  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"

  }
}

resource "aws_route_table_association" "private_assoc" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# -------------------------
# SECURITY GROUPS
# -------------------------
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
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

  tags = {
    Name = "${var.project_name}-alb-sg"

  }
}

resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "EC2 security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App traffic from ALB"
    from_port       = var.api_port
    to_port         = var.api_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description = "SSH"
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
    Name = "${var.project_name}-ec2-sg"

  }
}

resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-sg"
  description = "RDS security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"

  }
}

resource "aws_security_group" "elasticache_sg" {
  name        = "${var.project_name}-elasticache-sg"
  description = "ElastiCache security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Redis from EC2"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-elasticache-sg"

  }
}

# -------------------------
# ALB + WAF
# -------------------------
resource "aws_lb" "api_alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.project_name}-alb"

  }
}

resource "aws_wafv2_web_acl" "api" {
  name  = "${var.project_name}-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-waf-common"
      sampled_requests_enabled   = true
    }
  }
}

resource "aws_wafv2_web_acl_association" "alb_assoc" {
  resource_arn = aws_lb.api_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.api.arn
}

resource "aws_lb_target_group" "api_tg" {
  name        = "${var.project_name}-tg"
  port        = var.api_port
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTPS"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-tg"

  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.api_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.api_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_tg.arn
  }
}

# Route 53 API alias disabled for now — restore with ACM / DNS when ready
/*
resource "aws_route53_record" "api" {
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.api_alb.dns_name
    zone_id                = aws_lb.api_alb.zone_id
    evaluate_target_health = true
  }
}
*/

# -------------------------
# COMPUTE (ASG)
# -------------------------
resource "aws_launch_template" "api_lt" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.generated.key_name

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = base64encode(file("${path.module}/userdata.sh"))

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name           = "${var.project_name}-api"
      environment    = "Not production"
      classification = "moderate"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "api_asg" {
  name                = "${var.project_name}-asg"
  desired_capacity    = var.asg_desired
  min_size            = var.asg_min
  max_size            = var.asg_max
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.api_tg.arn]
  health_check_type   = "EC2"

  launch_template {
    id      = aws_launch_template.api_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-api"
    propagate_at_launch = true
  }

  tag {
    key                 = "environment"
    value               = "Not production"
    propagate_at_launch = true
  }

  tag {
    key                 = "classification"
    value               = "moderate"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -------------------------
# RDS
# -------------------------
resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.public[*].id

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-db-subnet-group"

  }
}

locals {
  rds_from_snapshot = var.rds_snapshot_identifier != null && trimspace(var.rds_snapshot_identifier) != ""
}

resource "aws_db_instance" "this" {
  identifier              = "${var.project_name}-rds"
  instance_class          = var.db_instance_class
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  multi_az                = false
  publicly_accessible     = true
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 1

  snapshot_identifier = local.rds_from_snapshot ? var.rds_snapshot_identifier : null

  allocated_storage = local.rds_from_snapshot ? null : var.db_allocated_storage
  engine            = local.rds_from_snapshot ? null : "mysql"
  engine_version    = local.rds_from_snapshot ? null : "8.0"
  db_name           = local.rds_from_snapshot ? null : var.db_name
  username          = local.rds_from_snapshot ? null : var.db_username
  password          = local.rds_from_snapshot ? null : var.db_password

  tags = {
    Name = "${var.project_name}-rds"

  }
}

# -------------------------
# ELASTICACHE
# -------------------------
resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.project_name}-cache-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-cache-subnet-group"

  }
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id       = "${var.project_name}-redis"
  description                = "Redis replication group for ${var.project_name}"
  engine                     = "redis"
  engine_version             = "7.0"
  node_type                  = var.cache_node_type
  num_cache_clusters         = 2
  port                       = 6379
  parameter_group_name       = "default.redis7"
  automatic_failover_enabled = true
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  subnet_group_name          = aws_elasticache_subnet_group.this.name
  security_group_ids         = [aws_security_group.elasticache_sg.id]

  tags = {
    Name = "${var.project_name}-redis"
    Env  = "Not production"
  }
}

# -------------------------
# S3 + SECRETS MANAGER
# -------------------------
resource "aws_s3_bucket" "app" {
  bucket = var.s3_bucket_name

  tags = {
    Name           = "${var.project_name}-bucket"
    environment    = "Not production"
    classification = "moderate"
  }
}

resource "aws_secretsmanager_secret" "db" {
  name = coalesce(var.db_secret_name, "${var.project_name}/db")

  tags = {
    Name           = coalesce(var.db_secret_name, "${var.project_name}/db")
    environment    = "Not production"
    classification = "moderate"
  }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    engine   = "mysql"
    host     = aws_db_instance.this.address
    port     = 3306
    dbname   = var.db_name
  })
}

# -------------------------
# CLOUDWATCH ALARMS
# -------------------------
resource "aws_cloudwatch_metric_alarm" "asg_cpu_gt_60_10m" {
  alarm_name          = "${var.project_name}-asg-cpu-gt-60-10m"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Maximum"
  threshold           = 60
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.api_asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_4xx" {
  alarm_name          = "${var.project_name}-alb-4xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_4XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 100
  dimensions = {
    LoadBalancer = aws_lb.api_alb.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project_name}-alb-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  dimensions = {
    LoadBalancer = aws_lb.api_alb.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "cache_freeable_memory_low" {
  alarm_name          = "${var.project_name}-cache-freeable-memory-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeableMemory"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 300000000
  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.this.replication_group_id
  }
}

resource "aws_cloudwatch_metric_alarm" "cache_connections_high" {
  alarm_name          = "${var.project_name}-cache-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CurrConnections"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Maximum"
  threshold           = 25
  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.this.replication_group_id
  }
}

resource "aws_cloudwatch_metric_alarm" "cache_cpu_high" {
  alarm_name          = "${var.project_name}-cache-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Maximum"
  threshold           = 80
  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.this.replication_group_id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_70" {
  alarm_name          = "${var.project_name}-rds-cpu-70"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 70
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_90" {
  alarm_name          = "${var.project_name}-rds-cpu-90"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 90
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_write_iops" {
  alarm_name          = "${var.project_name}-rds-write-iops-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "WriteIOPS"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_read_iops" {
  alarm_name          = "${var.project_name}-rds-read-iops-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ReadIOPS"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage_low" {
  alarm_name          = "${var.project_name}-rds-free-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 2147483648
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.id
  }
}
