output "forwarder_lambda_arn" {
  description = "The ARN for the Lambda function for the audit forwarder"
  value       = aws_lambda_function.forwarder.arn
}

output "forwarder_url" {
  description = "The HTTP URL endpoint for the audit forwarder"
  value       = var.forwarding_endpoint == "api_gateway" ? aws_api_gateway_stage.forwarder[0].invoke_url : aws_lambda_function_url.forwarder[0].function_url
}

output "forwarder_lambda_iam_role_name" {
  description = "The name for the lambda IAM execution role"
  value       = "${var.forwarder_name_prefix}-lambda"
}

output "forwarder_lambda_iam_role_arn" {
  description = "The ARN for the lambda IAM execution role"
  value       = aws_iam_role.forwarder.arn
}

output "forwarder_stream_name" {
  description = "The name for the Kinesis Firehose Delivery Stream"
  value       = "${var.forwarder_name_prefix}-stream"
}

output "forwarder_stream_iam_role_arn" {
  description = "The ARN for the Kinesis Firehose Delivery Stream"
  value       = aws_iam_role.stream.arn
}
