# Application Load Balancer Module
# Creates an Application Load Balancer with target groups, listeners, and routing rules

# Common Tags Module
module "tags" {
  source = "../common-tags"

  environment = var.environment
  service     = var.service_name
  team        = var.team
  owner       = var.owner
  cost_center = var.cost_center
  project     = var.project
  data_class  = var.data_class

  additional_tags = var.additional_tags
}

# Application Load Balancer
resource "aws_lb" "this" {
  name               = var.name
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  enable_http2               = var.enable_http2
  idle_timeout               = var.idle_timeout
  ip_address_type            = var.ip_address_type

  # Access logs configuration
  dynamic "access_logs" {
    for_each = var.access_logs != null ? [var.access_logs] : []
    content {
      bucket  = access_logs.value.bucket
      enabled = access_logs.value.enabled
      prefix  = access_logs.value.prefix
    }
  }

  tags = merge(
    local.required_tags,
    {
      Name        = var.name
      Description = "Application Load Balancer ${var.name}"
      Component   = "load-balancer"
    }
  )
}

# Target Groups
resource "aws_lb_target_group" "this" {
  for_each = var.target_groups

  name     = "${var.name}-${each.key}"
  port     = each.value.port
  protocol = each.value.protocol
  vpc_id   = var.vpc_id

  target_type          = each.value.target_type
  deregistration_delay = each.value.deregistration_delay

  # Health check configuration
  health_check {
    enabled             = try(each.value.health_check.enabled, true)
    healthy_threshold   = try(each.value.health_check.healthy_threshold, 3)
    interval            = try(each.value.health_check.interval, 30)
    matcher             = try(each.value.health_check.matcher, "200")
    path                = try(each.value.health_check.path, "/health")
    protocol            = try(each.value.health_check.protocol, "HTTP")
    timeout             = try(each.value.health_check.timeout, 5)
    unhealthy_threshold = try(each.value.health_check.unhealthy_threshold, 2)
  }

  # Stickiness configuration
  dynamic "stickiness" {
    for_each = try(each.value.stickiness.enabled, false) ? [each.value.stickiness] : []
    content {
      type            = stickiness.value.type
      cookie_duration = stickiness.value.cookie_duration
      enabled         = stickiness.value.enabled
    }
  }

  tags = merge(
    local.required_tags,
    {
      Name        = "${var.name}-${each.key}"
      Description = "Target group for ${var.name} - ${each.key}"
      Component   = "target-group"
    }
  )

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = each.value.target_type != "lambda" || each.value.protocol == "HTTP"
      error_message = "Lambda target type requires HTTP protocol."
    }

    precondition {
      condition     = try(each.value.health_check.timeout, 5) < try(each.value.health_check.interval, 30)
      error_message = "Health check timeout must be less than the interval."
    }
  }
}

# HTTP Listeners
resource "aws_lb_listener" "http" {
  for_each = var.http_listeners

  load_balancer_arn = aws_lb.this.arn
  port              = each.value.port
  protocol          = each.value.protocol

  # Default action
  dynamic "default_action" {
    for_each = [each.value.default_action]
    content {
      type = default_action.value.type

      # Forward to target group
      target_group_arn = default_action.value.type == "forward" && default_action.value.target_group_key != null ? (
        aws_lb_target_group.this[default_action.value.target_group_key].arn
      ) : null

      # Redirect action
      dynamic "redirect" {
        for_each = default_action.value.type == "redirect" && default_action.value.redirect != null ? [default_action.value.redirect] : []
        content {
          port        = redirect.value.port
          protocol    = redirect.value.protocol
          status_code = redirect.value.status_code
        }
      }

      # Fixed response action
      dynamic "fixed_response" {
        for_each = default_action.value.type == "fixed-response" && default_action.value.fixed_response != null ? [default_action.value.fixed_response] : []
        content {
          content_type = fixed_response.value.content_type
          message_body = fixed_response.value.message_body
          status_code  = fixed_response.value.status_code
        }
      }
    }
  }

  tags = merge(
    local.required_tags,
    {
      Name        = "${var.name}-http-${each.key}"
      Description = "HTTP listener for ${var.name}"
      Component   = "listener"
    }
  )
}

# HTTPS Listeners
resource "aws_lb_listener" "https" {
  for_each = var.https_listeners

  load_balancer_arn = aws_lb.this.arn
  port              = each.value.port
  protocol          = each.value.protocol
  ssl_policy        = each.value.ssl_policy
  certificate_arn   = each.value.certificate_arn

  # Default action
  dynamic "default_action" {
    for_each = [each.value.default_action]
    content {
      type = default_action.value.type

      # Forward to target group
      target_group_arn = default_action.value.type == "forward" && default_action.value.target_group_key != null ? (
        aws_lb_target_group.this[default_action.value.target_group_key].arn
      ) : null

      # Fixed response action
      dynamic "fixed_response" {
        for_each = default_action.value.type == "fixed-response" && default_action.value.fixed_response != null ? [default_action.value.fixed_response] : []
        content {
          content_type = fixed_response.value.content_type
          message_body = fixed_response.value.message_body
          status_code  = fixed_response.value.status_code
        }
      }
    }
  }

  tags = merge(
    local.required_tags,
    {
      Name        = "${var.name}-https-${each.key}"
      Description = "HTTPS listener for ${var.name}"
      Component   = "listener"
    }
  )
}

# Listener Rules (Path-based routing)
resource "aws_lb_listener_rule" "this" {
  for_each = var.listener_rules

  listener_arn = try(
    aws_lb_listener.http[each.value.listener_key].arn,
    aws_lb_listener.https[each.value.listener_key].arn,
  )

  priority = each.value.priority

  # Conditions
  dynamic "condition" {
    for_each = each.value.conditions
    content {
      dynamic "path_pattern" {
        for_each = condition.value.path_pattern != null ? [condition.value.path_pattern] : []
        content {
          values = path_pattern.value
        }
      }

      dynamic "host_header" {
        for_each = condition.value.host_header != null ? [condition.value.host_header] : []
        content {
          values = host_header.value
        }
      }
    }
  }

  # Actions
  dynamic "action" {
    for_each = each.value.actions
    content {
      type  = action.value.type
      order = action.key + 1

      # Forward to target group
      target_group_arn = action.value.type == "forward" && action.value.target_group_key != null ? (
        aws_lb_target_group.this[action.value.target_group_key].arn
      ) : null

      # Redirect action
      dynamic "redirect" {
        for_each = action.value.type == "redirect" && action.value.redirect != null ? [action.value.redirect] : []
        content {
          port        = redirect.value.port
          protocol    = redirect.value.protocol
          status_code = redirect.value.status_code
          host        = redirect.value.host
          path        = redirect.value.path
        }
      }

      # Fixed response action
      dynamic "fixed_response" {
        for_each = action.value.type == "fixed-response" && action.value.fixed_response != null ? [action.value.fixed_response] : []
        content {
          content_type = fixed_response.value.content_type
          message_body = fixed_response.value.message_body
          status_code  = fixed_response.value.status_code
        }
      }
    }
  }

  tags = merge(
    local.required_tags,
    {
      Name        = "${var.name}-rule-${each.key}"
      Description = "Listener rule for ${var.name} - ${each.key}"
      Component   = "listener-rule"
    }
  )
}
