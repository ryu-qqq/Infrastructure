# Required Tags Policy
# Ensures all AWS resources have required tags

package terraform.tagging.required_tags

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Required tags that must be present on all resources
required_tags := [
    "Environment",
    "Service",
    "Team",
    "Owner",
    "CostCenter",
    "ManagedBy",
    "Project",
]

# Valid values for specific tags
valid_environments := ["dev", "staging", "prod"]

valid_managed_by := ["terraform", "manual", "cloudformation", "cdk"]

# Get all resources with tags from terraform plan
resources[resource] {
    some path, value
    walk(input.planned_values.root_module, [path, value])
    value.type
    value.values.tags
    resource := {
        "address": value.address,
        "type": value.type,
        "tags": value.values.tags,
    }
}

# Check if a resource has all required tags
missing_required_tags[result] {
    resource := resources[_]
    tag := required_tags[_]
    not resource.tags[tag]
    result := {
        "resource": resource.address,
        "resource_type": resource.type,
        "missing_tag": tag,
        "message": sprintf("Resource '%s' is missing required tag: %s", [resource.address, tag]),
    }
}

# Validate Environment tag values
invalid_environment_tag[result] {
    resource := resources[_]
    env := resource.tags.Environment
    not env in valid_environments
    result := {
        "resource": resource.address,
        "resource_type": resource.type,
        "tag": "Environment",
        "value": env,
        "message": sprintf("Resource '%s' has invalid Environment tag value '%s'. Must be one of: %v", [resource.address, env, valid_environments]),
    }
}

# Validate ManagedBy tag values
invalid_managed_by_tag[result] {
    resource := resources[_]
    managed_by := resource.tags.ManagedBy
    not managed_by in valid_managed_by
    result := {
        "resource": resource.address,
        "resource_type": resource.type,
        "tag": "ManagedBy",
        "value": managed_by,
        "message": sprintf("Resource '%s' has invalid ManagedBy tag value '%s'. Must be one of: %v", [resource.address, managed_by, valid_managed_by]),
    }
}

# Validate kebab-case format for specific tags
invalid_tag_format[result] {
    resource := resources[_]
    kebab_case_tags := ["Service", "Team", "CostCenter", "Project"]
    tag_name := kebab_case_tags[_]
    tag_value := resource.tags[tag_name]
    not regex.match(`^[a-z][a-z0-9-]*[a-z0-9]$`, tag_value)
    result := {
        "resource": resource.address,
        "resource_type": resource.type,
        "tag": tag_name,
        "value": tag_value,
        "message": sprintf("Resource '%s' has invalid %s tag format '%s'. Must use kebab-case (lowercase letters, numbers, hyphens only)", [resource.address, tag_name, tag_value]),
    }
}

# Validate Owner tag format (email or kebab-case)
invalid_owner_format[result] {
    resource := resources[_]
    owner := resource.tags.Owner
    not regex.match(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`, owner)
    not regex.match(`^[a-z][a-z0-9-]*[a-z0-9]$`, owner)
    result := {
        "resource": resource.address,
        "resource_type": resource.type,
        "tag": "Owner",
        "value": owner,
        "message": sprintf("Resource '%s' has invalid Owner tag format '%s'. Must be a valid email or kebab-case identifier", [resource.address, owner]),
    }
}

# Main deny rule - combine all violations
deny[msg] {
    violation := missing_required_tags[_]
    msg := violation.message
}

deny[msg] {
    violation := invalid_environment_tag[_]
    msg := violation.message
}

deny[msg] {
    violation := invalid_managed_by_tag[_]
    msg := violation.message
}

deny[msg] {
    violation := invalid_tag_format[_]
    msg := violation.message
}

deny[msg] {
    violation := invalid_owner_format[_]
    msg := violation.message
}

# Helper rule for reporting
violations := array.concat(
    array.concat(
        array.concat(
            array.concat(
                [v | v := missing_required_tags[_]],
                [v | v := invalid_environment_tag[_]]
            ),
            [v | v := invalid_managed_by_tag[_]]
        ),
        [v | v := invalid_tag_format[_]]
    ),
    [v | v := invalid_owner_format[_]]
)
