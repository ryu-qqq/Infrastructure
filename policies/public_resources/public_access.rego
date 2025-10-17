# Public Resource Access Policy
# Ensures AWS resources are not unnecessarily exposed to the public internet

package terraform.security.public_resources

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Get S3 buckets
s3_buckets[bucket] {
    some path, value
    walk(input.planned_values.root_module, [path, value])
    value.type == "aws_s3_bucket"
    bucket := {
        "address": value.address,
        "bucket": value.values.bucket,
        "tags": value.values.tags,
    }
}

# Get S3 bucket public access block configurations
s3_public_access_blocks[block] {
    some path, value
    walk(input.planned_values.root_module, [path, value])
    value.type == "aws_s3_bucket_public_access_block"
    block := {
        "address": value.address,
        "bucket": value.values.bucket,
        "block_public_acls": value.values.block_public_acls,
        "block_public_policy": value.values.block_public_policy,
        "ignore_public_acls": value.values.ignore_public_acls,
        "restrict_public_buckets": value.values.restrict_public_buckets,
    }
}

# Get RDS instances
rds_instances[rds] {
    some path, value
    walk(input.planned_values.root_module, [path, value])
    value.type == "aws_db_instance"
    rds := {
        "address": value.address,
        "identifier": value.values.identifier,
        "publicly_accessible": value.values.publicly_accessible,
        "tags": value.values.tags,
    }
}

# Get EC2 instances
ec2_instances[instance] {
    some path, value
    walk(input.planned_values.root_module, [path, value])
    value.type == "aws_instance"
    instance := {
        "address": value.address,
        "tags": value.values.tags,
        "associate_public_ip_address": value.values.associate_public_ip_address,
        "subnet_id": value.values.subnet_id,
    }
}

# Get Load Balancers
load_balancers[lb] {
    some path, value
    walk(input.planned_values.root_module, [path, value])
    value.type in ["aws_lb", "aws_alb", "aws_elb"]
    lb := {
        "address": value.address,
        "name": value.values.name,
        "internal": value.values.internal,
        "load_balancer_type": value.values.load_balancer_type,
        "tags": value.values.tags,
    }
}

# Get Lambda function URLs
lambda_function_urls[url] {
    some path, value
    walk(input.planned_values.root_module, [path, value])
    value.type == "aws_lambda_function_url"
    url := {
        "address": value.address,
        "function_name": value.values.function_name,
        "authorization_type": value.values.authorization_type,
    }
}

# Helper to check if environment is production
is_production(tags) if {
    tags.Environment == "prod"
}

is_production(tags) if {
    tags.Environment == "production"
}

# S3 bucket without public access block
s3_missing_public_access_block[result] {
    bucket := s3_buckets[_]
    bucket_id := bucket.bucket

    # Check if there's a public access block for this bucket
    not any_public_access_block_for_bucket(bucket_id)

    result := {
        "resource": bucket.address,
        "bucket": bucket_id,
        "message": sprintf("S3 bucket '%s' does not have a public access block configuration. Add aws_s3_bucket_public_access_block to prevent accidental public exposure", [bucket.address]),
    }
}

any_public_access_block_for_bucket(bucket_id) {
    block := s3_public_access_blocks[_]
    block.bucket == bucket_id
}

# S3 bucket with public access enabled
s3_public_access_enabled[result] {
    block := s3_public_access_blocks[_]

    # Check if any public access setting is not blocking
    not block.block_public_acls
    or not block.block_public_policy
    or not block.ignore_public_acls
    or not block.restrict_public_buckets

    result := {
        "resource": block.address,
        "bucket": block.bucket,
        "block_public_acls": block.block_public_acls,
        "block_public_policy": block.block_public_policy,
        "message": sprintf("S3 bucket '%s' has public access enabled. All public access block settings should be true", [block.address]),
    }
}

# RDS instance publicly accessible
rds_publicly_accessible[result] {
    rds := rds_instances[_]
    rds.publicly_accessible == true

    result := {
        "resource": rds.address,
        "identifier": rds.identifier,
        "message": sprintf("RDS instance '%s' is publicly accessible. This is a security risk for databases", [rds.address]),
    }
}

# Production RDS must not be public
production_rds_public[result] {
    rds := rds_instances[_]
    rds.publicly_accessible == true
    is_production(rds.tags)

    result := {
        "resource": rds.address,
        "identifier": rds.identifier,
        "environment": "production",
        "message": sprintf("Production RDS instance '%s' is publicly accessible. This is a critical security violation", [rds.address]),
    }
}

# EC2 instance with public IP in production
production_ec2_public_ip[result] {
    instance := ec2_instances[_]
    instance.associate_public_ip_address == true
    is_production(instance.tags)

    result := {
        "resource": instance.address,
        "message": sprintf("Production EC2 instance '%s' has a public IP address. Consider using NAT Gateway or Load Balancer instead", [instance.address]),
    }
}

# Internet-facing load balancer in production without justification
production_public_lb[result] {
    lb := load_balancers[_]
    lb.internal == false
    is_production(lb.tags)

    # Check if there's a justification tag
    not lb.tags.PublicAccess

    result := {
        "resource": lb.address,
        "name": lb.name,
        "message": sprintf("Production load balancer '%s' is internet-facing without a 'PublicAccess' justification tag", [lb.address]),
    }
}

# Lambda function URL without authentication
lambda_url_without_auth[result] {
    url := lambda_function_urls[_]
    url.authorization_type == "NONE"

    result := {
        "resource": url.address,
        "function": url.function_name,
        "message": sprintf("Lambda function URL '%s' has no authentication (NONE). Consider using IAM authentication or implement custom authorization", [url.address]),
    }
}

# Main deny rules for critical violations
deny[msg] {
    violation := production_rds_public[_]
    msg := violation.message
}

deny[msg] {
    violation := rds_publicly_accessible[_]
    msg := violation.message
}

deny[msg] {
    violation := s3_public_access_enabled[_]
    msg := violation.message
}

# Warnings for less critical issues
warn[msg] {
    violation := s3_missing_public_access_block[_]
    msg := violation.message
}

warn[msg] {
    violation := production_ec2_public_ip[_]
    msg := violation.message
}

warn[msg] {
    violation := production_public_lb[_]
    msg := violation.message
}

warn[msg] {
    violation := lambda_url_without_auth[_]
    msg := violation.message
}

# Helper rule for reporting
violations := array.concat(
    array.concat(
        [v | v := production_rds_public[_]],
        [v | v := rds_publicly_accessible[_]]
    ),
    array.concat(
        array.concat(
            [v | v := s3_public_access_enabled[_]],
            [v | v := s3_missing_public_access_block[_]]
        ),
        array.concat(
            array.concat(
                [v | v := production_ec2_public_ip[_]],
                [v | v := production_public_lb[_]]
            ),
            [v | v := lambda_url_without_auth[_]]
        )
    )
)
