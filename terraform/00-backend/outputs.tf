output "tfstate_bucket_name" {
  description = "Nombre del bucket S3 a usar como backend remoto en los demás módulos."
  value       = aws_s3_bucket.tfstate.id
}

output "tflock_table_name" {
  description = "Nombre de la tabla DynamoDB a usar para locking en los demás módulos."
  value       = aws_dynamodb_table.tflock.name
}
