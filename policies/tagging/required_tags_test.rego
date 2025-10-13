# Test cases for required tags policy

package terraform.tagging.required_tags

import future.keywords.if

# Test data: Valid resource with all required tags
test_valid_resource if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_instance.valid",
                    "type": "aws_instance",
                    "values": {
                        "tags": {
                            "Environment": "prod",
                            "Service": "api",
                            "Team": "platform-team",
                            "Owner": "platform-team@company.com",
                            "CostCenter": "infrastructure",
                            "ManagedBy": "terraform",
                            "Project": "infrastructure",
                        },
                    },
                }],
            },
        },
    }

    count(missing_required_tags) == 0
    count(invalid_environment_tag) == 0
    count(invalid_managed_by_tag) == 0
    count(invalid_tag_format) == 0
    count(invalid_owner_format) == 0
}

# Test data: Resource missing required tags
test_missing_tags if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_instance.missing_tags",
                    "type": "aws_instance",
                    "values": {
                        "tags": {
                            "Environment": "prod",
                            "Service": "api",
                        },
                    },
                }],
            },
        },
    }

    count(missing_required_tags) == 5  # Missing Team, Owner, CostCenter, ManagedBy, Project
}

# Test data: Invalid environment value
test_invalid_environment if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_instance.invalid_env",
                    "type": "aws_instance",
                    "values": {
                        "tags": {
                            "Environment": "production",  # Should be "prod"
                            "Service": "api",
                            "Team": "platform-team",
                            "Owner": "platform-team",
                            "CostCenter": "infrastructure",
                            "ManagedBy": "terraform",
                            "Project": "infrastructure",
                        },
                    },
                }],
            },
        },
    }

    count(invalid_environment_tag) == 1
}

# Test data: Invalid kebab-case format
test_invalid_kebab_case if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_instance.invalid_format",
                    "type": "aws_instance",
                    "values": {
                        "tags": {
                            "Environment": "prod",
                            "Service": "MyAPI",  # Should be "my-api"
                            "Team": "platform_team",  # Should be "platform-team"
                            "Owner": "platform-team",
                            "CostCenter": "Infrastructure",  # Should be "infrastructure"
                            "ManagedBy": "terraform",
                            "Project": "infrastructure",
                        },
                    },
                }],
            },
        },
    }

    count(invalid_tag_format) == 3
}

# Test data: Valid email for Owner
test_valid_email_owner if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_instance.valid_email",
                    "type": "aws_instance",
                    "values": {
                        "tags": {
                            "Environment": "prod",
                            "Service": "api",
                            "Team": "platform-team",
                            "Owner": "john.doe@company.com",
                            "CostCenter": "infrastructure",
                            "ManagedBy": "terraform",
                            "Project": "infrastructure",
                        },
                    },
                }],
            },
        },
    }

    count(invalid_owner_format) == 0
}

# Test data: Invalid Owner format
test_invalid_owner_format_test if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_instance.invalid_owner",
                    "type": "aws_instance",
                    "values": {
                        "tags": {
                            "Environment": "prod",
                            "Service": "api",
                            "Team": "platform-team",
                            "Owner": "John_Doe",  # Invalid: uses underscore
                            "CostCenter": "infrastructure",
                            "ManagedBy": "terraform",
                            "Project": "infrastructure",
                        },
                    },
                }],
            },
        },
    }

    count(invalid_owner_format) == 1
}
