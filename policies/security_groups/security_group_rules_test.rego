# Security Group Rules Policy Tests

package terraform.security.security_groups

import future.keywords.if

# Test data - valid security group
test_valid_security_group if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_security_group.valid",
                    "type": "aws_security_group",
                    "values": {
                        "name": "valid-security-group",
                        "description": "This is a properly configured security group for the application tier",
                        "ingress": [{
                            "from_port": 443,
                            "to_port": 443,
                            "protocol": "tcp",
                            "cidr_blocks": ["10.0.0.0/8"],
                        }],
                        "egress": [{
                            "from_port": 443,
                            "to_port": 443,
                            "protocol": "tcp",
                            "cidr_blocks": ["0.0.0.0/0"],
                        }],
                    },
                }],
            },
        },
    }
    count(deny) == 0
}

# Test data - SSH exposed to internet
test_ssh_exposed_to_internet if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_security_group.bad_ssh",
                    "type": "aws_security_group",
                    "values": {
                        "name": "bad-ssh-sg",
                        "description": "Security group with SSH exposed",
                        "ingress": [{
                            "from_port": 22,
                            "to_port": 22,
                            "protocol": "tcp",
                            "cidr_blocks": ["0.0.0.0/0"],
                        }],
                        "egress": [],
                    },
                }],
            },
        },
    }
    count(deny) > 0
    some msg in deny
    contains(msg, "dangerous port 22")
}

# Test data - all traffic allowed
test_all_traffic_allowed if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_security_group.all_traffic",
                    "type": "aws_security_group",
                    "values": {
                        "name": "all-traffic-sg",
                        "description": "Overly permissive security group",
                        "ingress": [{
                            "from_port": 0,
                            "to_port": 0,
                            "protocol": "-1",
                            "cidr_blocks": ["0.0.0.0/0"],
                        }],
                        "egress": [],
                    },
                }],
            },
        },
    }
    count(deny) > 0
    some msg in deny
    contains(msg, "all traffic")
}

# Test data - missing description
test_missing_description if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_security_group.no_desc",
                    "type": "aws_security_group",
                    "values": {
                        "name": "no-description-sg",
                        "description": "",
                        "ingress": [{
                            "from_port": 443,
                            "to_port": 443,
                            "protocol": "tcp",
                            "cidr_blocks": ["10.0.0.0/8"],
                        }],
                        "egress": [],
                    },
                }],
            },
        },
    }
    count(warn) > 0
    some msg in warn
    contains(msg, "description")
}

# Test data - database port exposed
test_database_port_exposed if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_security_group.db_exposed",
                    "type": "aws_security_group",
                    "values": {
                        "name": "database-sg",
                        "description": "Database security group with PostgreSQL exposed",
                        "ingress": [{
                            "from_port": 5432,
                            "to_port": 5432,
                            "protocol": "tcp",
                            "cidr_blocks": ["0.0.0.0/0"],
                        }],
                        "egress": [],
                    },
                }],
            },
        },
    }
    count(deny) > 0
    some msg in deny
    contains(msg, "dangerous port 5432")
}

# Test data - IPv6 exposure
test_ipv6_ssh_exposed if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_security_group.ipv6_ssh",
                    "type": "aws_security_group",
                    "values": {
                        "name": "ipv6-ssh-sg",
                        "description": "Security group with IPv6 SSH exposed",
                        "ingress": [{
                            "from_port": 22,
                            "to_port": 22,
                            "protocol": "tcp",
                            "cidr_blocks": [],
                            "ipv6_cidr_blocks": ["::/0"],
                        }],
                        "egress": [],
                    },
                }],
            },
        },
    }
    count(deny) > 0
    some msg in deny
    contains(msg, "IPv6")
}

# Test data - security group rule with dangerous port
test_sg_rule_dangerous_port if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_security_group_rule.rdp_rule",
                    "type": "aws_security_group_rule",
                    "values": {
                        "type": "ingress",
                        "from_port": 3389,
                        "to_port": 3389,
                        "protocol": "tcp",
                        "cidr_blocks": ["0.0.0.0/0"],
                        "description": "RDP access",
                    },
                }],
            },
        },
    }
    count(deny) > 0
    some msg in deny
    contains(msg, "dangerous port 3389")
}

# Test data - generic description
test_generic_description if {
    input := {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "address": "aws_security_group.generic",
                    "type": "aws_security_group",
                    "values": {
                        "name": "generic-sg",
                        "description": "Managed by Terraform",
                        "ingress": [{
                            "from_port": 443,
                            "to_port": 443,
                            "protocol": "tcp",
                            "cidr_blocks": ["10.0.0.0/8"],
                        }],
                        "egress": [],
                    },
                }],
            },
        },
    }
    count(warn) > 0
    some msg in warn
    contains(msg, "generic description")
}
