# Resource Naming Convention Policy
# Ensures all AWS resources follow kebab-case naming standards

package terraform.naming.resource_naming

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Get all resources with names from terraform plan
resources[resource] {
    some path, value
    walk(input.planned_values.root_module, [path, value])
    value.type
    # Check if resource has a name field
    name_field := get_name_field(value)
    name_field
    resource := {
        "address": value.address,
        "type": value.type,
        "name": name_field,
    }
}

# Helper to get name field from resource
get_name_field(resource) := name if {
    name := resource.values.tags.Name
} else := name if {
    name := resource.values.name
} else := name if {
    name := resource.values.bucket
} else := null

# Kebab-case validation regex
# Must start with lowercase letter, contain only lowercase letters, numbers, and hyphens, end with letter or number
kebab_case_regex := `^[a-z][a-z0-9-]*[a-z0-9]$`

# Resource types that should follow kebab-case naming
kebab_case_resource_types := {
    "aws_instance",
    "aws_ecs_cluster",
    "aws_ecs_service",
    "aws_ecs_task_definition",
    "aws_lb",
    "aws_lb_target_group",
    "aws_security_group",
    "aws_db_instance",
    "aws_dynamodb_table",
    "aws_elasticache_cluster",
    "aws_lambda_function",
    "aws_sns_topic",
    "aws_sqs_queue",
    "aws_cloudwatch_log_group",
    "aws_iam_role",
    "aws_iam_policy",
}

# Resource types that have special naming rules (e.g., S3 buckets can have dots)
special_naming_rules := {
    "aws_s3_bucket": `^[a-z0-9][a-z0-9.-]*[a-z0-9]$`,
    "aws_kms_alias": `^alias/[a-z][a-z0-9-]*[a-z0-9]$`,
    "aws_ecr_repository": `^[a-z0-9][a-z0-9/_-]*[a-z0-9]$`,
}

# Check for invalid kebab-case naming
invalid_resource_naming[result] {
    resource := resources[_]
    resource.type in kebab_case_resource_types
    not regex.match(kebab_case_regex, resource.name)
    result := {
        "resource": resource.address,
        "resource_type": resource.type,
        "name": resource.name,
        "message": sprintf("Resource '%s' has invalid name '%s'. Must use kebab-case (lowercase letters, numbers, hyphens only)", [resource.address, resource.name]),
    }
}

# Check for resources with special naming rules
invalid_special_naming[result] {
    resource := resources[_]
    special_regex := special_naming_rules[resource.type]
    not regex.match(special_regex, resource.name)
    result := {
        "resource": resource.address,
        "resource_type": resource.type,
        "name": resource.name,
        "message": sprintf("Resource '%s' has invalid name '%s' for resource type %s", [resource.address, resource.name, resource.type]),
    }
}

# Check for common naming mistakes
invalid_naming_patterns[result] {
    resource := resources[_]

    # Check for camelCase
    regex.match(`[a-z][A-Z]`, resource.name)
    result := {
        "resource": resource.address,
        "resource_type": resource.type,
        "name": resource.name,
        "message": sprintf("Resource '%s' uses camelCase '%s'. Use kebab-case instead", [resource.address, resource.name]),
    }
}

invalid_naming_patterns[result] {
    resource := resources[_]

    # Check for snake_case
    contains(resource.name, "_")
    not resource.type == "aws_ecr_repository"  # ECR allows underscores
    result := {
        "resource": resource.address,
        "resource_type": resource.type,
        "name": resource.name,
        "message": sprintf("Resource '%s' uses snake_case '%s'. Use kebab-case instead", [resource.address, resource.name]),
    }
}

invalid_naming_patterns[result] {
    resource := resources[_]

    # Check for uppercase letters
    regex.match(`[A-Z]`, resource.name)
    not startswith(resource.name, "alias/")  # Allow for KMS aliases
    result := {
        "resource": resource.address,
        "resource_type": resource.type,
        "name": resource.name,
        "message": sprintf("Resource '%s' contains uppercase letters '%s'. Use lowercase only", [resource.address, resource.name]),
    }
}

invalid_naming_patterns[result] {
    resource := resources[_]

    # Check for consecutive hyphens
    contains(resource.name, "--")
    result := {
        "resource": resource.address,
        "resource_type": resource.type,
        "name": resource.name,
        "message": sprintf("Resource '%s' contains consecutive hyphens '%s'. Use single hyphens only", [resource.address, resource.name]),
    }
}

invalid_naming_patterns[result] {
    resource := resources[_]

    # Check for starting with hyphen or number (except special cases)
    regex.match(`^[-0-9]`, resource.name)
    not resource.type in special_naming_rules
    result := {
        "resource": resource.address,
        "resource_type": resource.type,
        "name": resource.name,
        "message": sprintf("Resource '%s' starts with hyphen or number '%s'. Must start with lowercase letter", [resource.address, resource.name]),
    }
}

invalid_naming_patterns[result] {
    resource := resources[_]

    # Check for ending with hyphen
    endswith(resource.name, "-")
    result := {
        "resource": resource.address,
        "resource_type": resource.type,
        "name": resource.name,
        "message": sprintf("Resource '%s' ends with hyphen '%s'. Must end with letter or number", [resource.address, resource.name]),
    }
}

# Main deny rule
deny[msg] {
    violation := invalid_resource_naming[_]
    msg := violation.message
}

deny[msg] {
    violation := invalid_special_naming[_]
    msg := violation.message
}

deny[msg] {
    violation := invalid_naming_patterns[_]
    msg := violation.message
}

# Helper rule for reporting
violations := array.concat(
    array.concat(
        [v | v := invalid_resource_naming[_]],
        [v | v := invalid_special_naming[_]]
    ),
    [v | v := invalid_naming_patterns[_]]
)
