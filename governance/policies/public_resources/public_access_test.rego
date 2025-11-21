# Public Resource Access Policy Tests

package terraform.security.public_resources

import future.keywords.if

# Test data - S3 bucket with proper public access block
test_s3_with_public_access_block if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [
                    {
                        "address": "aws_s3_bucket.secure",
                        "type": "aws_s3_bucket",
                        "values": {
                            "bucket": "my-secure-bucket",
                            "tags": {"Environment": "prod"},
                        },
                    },
                    {
                        "address": "aws_s3_bucket_public_access_block.secure",
                        "type": "aws_s3_bucket_public_access_block",
                        "values": {
                            "bucket": "my-secure-bucket",
                            "block_public_acls": true,
                            "block_public_policy": true,
                            "ignore_public_acls": true,
                            "restrict_public_buckets": true,
                        },
                    },
                ],
            },
        },
    }
    count(deny) == 0
}

# Test data - S3 bucket without public access block
test_s3_missing_public_access_block if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_s3_bucket.insecure",
                    "type": "aws_s3_bucket",
                    "values": {
                        "bucket": "my-insecure-bucket",
                        "tags": {},
                    },
                }],
            },
        },
    }
    count(warn) > 0
    some msg in warn
    contains(msg, "public access block")
}

# Test data - S3 bucket with public access enabled
test_s3_public_access_enabled if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_s3_bucket_public_access_block.public",
                    "type": "aws_s3_bucket_public_access_block",
                    "values": {
                        "bucket": "my-public-bucket",
                        "block_public_acls": false,
                        "block_public_policy": false,
                        "ignore_public_acls": false,
                        "restrict_public_buckets": false,
                    },
                }],
            },
        },
    }
    count(deny) > 0
    some msg in deny
    contains(msg, "public access enabled")
}

# Test data - RDS publicly accessible
test_rds_publicly_accessible if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_db_instance.public_db",
                    "type": "aws_db_instance",
                    "values": {
                        "identifier": "public-database",
                        "publicly_accessible": true,
                        "tags": {"Environment": "dev"},
                    },
                }],
            },
        },
    }
    count(deny) > 0
    some msg in deny
    contains(msg, "publicly accessible")
}

# Test data - Production RDS publicly accessible (critical)
test_production_rds_public if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_db_instance.prod_public_db",
                    "type": "aws_db_instance",
                    "values": {
                        "identifier": "prod-database",
                        "publicly_accessible": true,
                        "tags": {"Environment": "prod"},
                    },
                }],
            },
        },
    }
    count(deny) > 0
    some msg in deny
    contains(msg, "critical security violation")
}

# Test data - Private RDS (valid)
test_rds_private if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_db_instance.private_db",
                    "type": "aws_db_instance",
                    "values": {
                        "identifier": "private-database",
                        "publicly_accessible": false,
                        "tags": {"Environment": "prod"},
                    },
                }],
            },
        },
    }
    count(deny) == 0
}

# Test data - Production EC2 with public IP
test_production_ec2_public_ip if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_instance.prod_public",
                    "type": "aws_instance",
                    "values": {
                        "associate_public_ip_address": true,
                        "tags": {"Environment": "prod"},
                    },
                }],
            },
        },
    }
    count(warn) > 0
    some msg in warn
    contains(msg, "public IP")
}

# Test data - Internet-facing load balancer without justification
test_public_lb_without_justification if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_lb.public_alb",
                    "type": "aws_lb",
                    "values": {
                        "name": "public-alb",
                        "internal": false,
                        "load_balancer_type": "application",
                        "tags": {"Environment": "prod"},
                    },
                }],
            },
        },
    }
    count(warn) > 0
    some msg in warn
    contains(msg, "PublicAccess")
}

# Test data - Internet-facing load balancer with justification (valid)
test_public_lb_with_justification if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_lb.justified_public_alb",
                    "type": "aws_lb",
                    "values": {
                        "name": "justified-alb",
                        "internal": false,
                        "load_balancer_type": "application",
                        "tags": {
                            "Environment": "prod",
                            "PublicAccess": "Web application frontend",
                        },
                    },
                }],
            },
        },
    }
    count(warn) == 0
}

# Test data - Lambda function URL without authentication
test_lambda_url_without_auth if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_lambda_function_url.public_url",
                    "type": "aws_lambda_function_url",
                    "values": {
                        "function_name": "my-function",
                        "authorization_type": "NONE",
                    },
                }],
            },
        },
    }
    count(warn) > 0
    some msg in warn
    contains(msg, "no authentication")
}

# Test data - Lambda function URL with IAM auth (valid)
test_lambda_url_with_auth if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_lambda_function_url.secure_url",
                    "type": "aws_lambda_function_url",
                    "values": {
                        "function_name": "my-secure-function",
                        "authorization_type": "AWS_IAM",
                    },
                }],
            },
        },
    }
    count(warn) == 0
}
