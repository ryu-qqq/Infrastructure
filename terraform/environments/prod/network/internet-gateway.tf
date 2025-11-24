# Internet Gateway

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  # Note: Imported existing IGW - tags defined for governance compliance
  # Tags are not modified in AWS due to IAM permission constraints
  tags = {
    Name        = "${var.environment}-igw"
    Owner       = var.team
    CostCenter  = var.cost_center
    Environment = var.environment
    Lifecycle   = var.lifecycle_stage
    DataClass   = var.data_class
    Service     = var.service_name
    Team        = var.team
    ManagedBy   = "terraform"
    Project     = var.project
    Component   = var.project
  }

  lifecycle {
    ignore_changes = [tags]
  }
}
