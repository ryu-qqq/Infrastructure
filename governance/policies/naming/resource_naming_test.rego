# Test cases for resource naming policy

package terraform.naming.resource_naming

import future.keywords.if

# Test data: Valid kebab-case naming
test_valid_kebab_case if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_instance.valid",
                    "type": "aws_instance",
                    "values": {
                        "name": "prod-api-web-01",
                        "tags": {
                            "Name": "prod-api-web-01",
                        },
                    },
                }],
            },
        },
    }

    count(invalid_resource_naming) == 0
    count(invalid_naming_patterns) == 0
}

# Test data: Invalid camelCase
test_invalid_camel_case if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_instance.camel",
                    "type": "aws_instance",
                    "values": {
                        "name": "prodApiWeb",
                        "tags": {
                            "Name": "prodApiWeb",
                        },
                    },
                }],
            },
        },
    }

    count(invalid_resource_naming) > 0
}

# Test data: Invalid snake_case
test_invalid_snake_case if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_instance.snake",
                    "type": "aws_instance",
                    "values": {
                        "name": "prod_api_web",
                        "tags": {
                            "Name": "prod_api_web",
                        },
                    },
                }],
            },
        },
    }

    count(invalid_naming_patterns) > 0
}

# Test data: Invalid uppercase
test_invalid_uppercase if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_instance.upper",
                    "type": "aws_instance",
                    "values": {
                        "name": "PROD-API-WEB",
                        "tags": {
                            "Name": "PROD-API-WEB",
                        },
                    },
                }],
            },
        },
    }

    count(invalid_naming_patterns) > 0
}

# Test data: Consecutive hyphens
test_consecutive_hyphens if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_instance.consecutive",
                    "type": "aws_instance",
                    "values": {
                        "name": "prod--api--web",
                        "tags": {
                            "Name": "prod--api--web",
                        },
                    },
                }],
            },
        },
    }

    count(invalid_naming_patterns) > 0
}

# Test data: Valid S3 bucket name
test_valid_s3_bucket if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_s3_bucket.logs",
                    "type": "aws_s3_bucket",
                    "values": {
                        "bucket": "myorg-prod-logs-123456789012",
                    },
                }],
            },
        },
    }

    count(invalid_special_naming) == 0
}

# Test data: Valid KMS alias
test_valid_kms_alias if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_kms_alias.rds",
                    "type": "aws_kms_alias",
                    "values": {
                        "name": "alias/rds-encryption",
                    },
                }],
            },
        },
    }

    count(invalid_special_naming) == 0
}

# Test data: Invalid KMS alias (no prefix)
test_invalid_kms_alias if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_kms_alias.invalid",
                    "type": "aws_kms_alias",
                    "values": {
                        "name": "rds-encryption",
                    },
                }],
            },
        },
    }

    count(invalid_special_naming) > 0
}
