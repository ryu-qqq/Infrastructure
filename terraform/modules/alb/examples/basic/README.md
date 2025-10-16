# ALB Module - Basic Example

This example demonstrates a basic Application Load Balancer configuration with:

- HTTP listener that redirects to HTTPS
- Single target group with health checks
- Default VPC and subnets
- Basic security group configuration

## Usage

```bash
# Initialize Terraform
terraform init

# Review the execution plan
terraform plan

# Apply the configuration
terraform apply

# Clean up resources
terraform destroy
```

## Configuration

This example creates:

1. **ALB**: Internet-facing load balancer in default VPC
2. **HTTP Listener**: Port 80 with redirect to HTTPS (port 443)
3. **Target Group**: Backend service on port 8080 with health checks
4. **Security Group**: Allows HTTP traffic on port 80

## Outputs

- `alb_dns_name`: DNS name of the load balancer
- `alb_arn`: ARN of the load balancer
- `target_group_arns`: Map of target group ARNs

## Prerequisites

- AWS account with appropriate permissions
- Default VPC with at least 2 subnets in different AZs
- Terraform >= 1.5.0

## Notes

- This example uses the default VPC for simplicity
- In production, use a dedicated VPC with private subnets
- Add SSL certificate for HTTPS listener in production
