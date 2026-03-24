output "vpc_id" {
  value = aws_vpc.main.id
}

output "alb_dns_name" {
  value = aws_lb.api_alb.dns_name
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "asg_name" {
  value = aws_autoscaling_group.api_asg.name
}

output "rds_endpoint" {
  value = aws_db_instance.this.endpoint
}

output "elasticache_primary_endpoint" {
  value = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "s3_bucket_name" {
  value = aws_s3_bucket.app.bucket
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}
