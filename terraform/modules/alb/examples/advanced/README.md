# ALB Module - Advanced Example

This example demonstrates an advanced Application Load Balancer configuration with:

- HTTP to HTTPS redirect
- HTTPS listener with SSL/TLS certificate
- Multiple target groups for different services
- Path-based routing (API, Admin, Primary app)
- Host-based routing
- Session stickiness
- Access logs to S3
- Custom health checks per target group

## Architecture

```
Internet
    |
    v
   ALB (HTTPS:443)
    |
    +-- /api/*     → API Target Group (Port 9090)
    +-- /admin/*   → Admin Target Group (Port 8081)
    +-- /*         → Primary Target Group (Port 8080)
```

## Usage

1. **Prerequisites**:
   - VPC with public subnets in at least 2 AZs
   - ACM certificate issued for your domain
   - S3 bucket for access logs (optional)

2. **Configure variables**:
```hcl
vpc_id             = "vpc-xxxxx"
certificate_domain = "example.com"
access_logs_bucket = "my-alb-logs-bucket"  # Optional
```

3. **Deploy**:
```bash
terraform init
terraform plan
terraform apply
```

4. **Test routing**:
```bash
# Primary app
curl https://your-alb-dns-name/

# API endpoint
curl https://your-alb-dns-name/api/users

# Admin panel
curl https://your-alb-dns-name/admin/dashboard
```

## Features Demonstrated

### Multi-Target Group Configuration
- **Primary**: Main application (port 8080)
- **API**: Backend API service (port 9090)
- **Admin**: Admin panel (port 8081)

### Path-Based Routing
- `/api/*` routes to API target group
- `/admin/*` routes to admin target group
- `/*` (default) routes to primary target group

### Host-Based Routing
- `app.example.com` → Primary target group
- `www.example.com` → Primary target group

### Health Checks
- Customized per target group
- Different paths: `/health`, `/api/health`, `/admin/health`
- Different intervals and thresholds

### Session Stickiness
- Enabled on primary target group
- 24-hour cookie duration
- Load balancer-generated cookies

### Security
- HTTP to HTTPS redirect
- TLS 1.3 security policy
- Security group with controlled access

## Outputs

- `alb_dns_name`: DNS name for the load balancer
- `alb_arn`: ARN of the load balancer
- `alb_zone_id`: Route53 zone ID for alias records
- `target_group_arns`: All target group ARNs
- `https_listener_arns`: HTTPS listener ARNs
- `listener_rule_arns`: All listener rule ARNs

## Production Considerations

1. **Certificates**: Use ACM for SSL/TLS certificates
2. **Access Logs**: Enable for troubleshooting and compliance
3. **Deletion Protection**: Enable in production
4. **WAF**: Consider AWS WAF integration
5. **Monitoring**: Set up CloudWatch alarms for target health
6. **DNS**: Create Route53 alias records pointing to ALB

## Clean Up

```bash
terraform destroy
```

## Cost Estimation

This example creates:
- 1 Application Load Balancer
- 3 Target Groups
- 2 Listeners (HTTP, HTTPS)
- 3 Listener Rules
- 1 Security Group

Estimated monthly cost: ~$20-30 (ALB hours + LCU charges, excluding data transfer)
