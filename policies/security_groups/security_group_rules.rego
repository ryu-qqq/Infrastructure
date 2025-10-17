# Security Group Rules Policy
# Ensures AWS Security Groups follow security best practices

package terraform.security.security_groups

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Get all security groups from terraform plan
security_groups[sg] {
    some path, value
    walk(input.planned_values.root_module, [path, value])
    value.type == "aws_security_group"
    sg := {
        "address": value.address,
        "name": value.values.name,
        "description": value.values.description,
        "ingress": value.values.ingress,
        "egress": value.values.egress,
    }
}

# Get all security group rules
security_group_rules[rule] {
    some path, value
    walk(input.planned_values.root_module, [path, value])
    value.type in ["aws_security_group_rule", "aws_vpc_security_group_ingress_rule", "aws_vpc_security_group_egress_rule"]
    rule := {
        "address": value.address,
        "type": value.type,
        "protocol": value.values.protocol,
        "from_port": value.values.from_port,
        "to_port": value.values.to_port,
        "cidr_blocks": get_cidr_blocks(value.values),
        "description": value.values.description,
    }
}

# Helper to get CIDR blocks
get_cidr_blocks(values) := cidrs if {
    cidrs := values.cidr_blocks
} else := [] if {
    true
}

# Dangerous ports that should not be open to 0.0.0.0/0
dangerous_ports := [
    22,   # SSH
    3389, # RDP
    3306, # MySQL
    5432, # PostgreSQL
    6379, # Redis
    27017, # MongoDB
    9200, # Elasticsearch
    5601, # Kibana
]

# Check for security groups with overly permissive ingress rules
overly_permissive_ingress[result] {
    sg := security_groups[_]
    ingress := sg.ingress[_]
    ingress.cidr_blocks[_] == "0.0.0.0/0"
    ingress.from_port == 0
    ingress.to_port == 0
    result := {
        "resource": sg.address,
        "name": sg.name,
        "rule": "all traffic",
        "message": sprintf("Security group '%s' allows all traffic (0.0.0.0/0) from anywhere. This is a critical security risk", [sg.address]),
    }
}

# Check for dangerous ports open to the internet
dangerous_port_exposure[result] {
    sg := security_groups[_]
    ingress := sg.ingress[_]
    ingress.cidr_blocks[_] == "0.0.0.0/0"
    port := dangerous_ports[_]
    ingress.from_port <= port
    ingress.to_port >= port
    result := {
        "resource": sg.address,
        "name": sg.name,
        "port": port,
        "message": sprintf("Security group '%s' exposes dangerous port %d to the internet (0.0.0.0/0)", [sg.address, port]),
    }
}

# Check for security group rules exposing dangerous ports
dangerous_port_in_rules[result] {
    rule := security_group_rules[_]
    contains(rule.type, "ingress")
    rule.cidr_blocks[_] == "0.0.0.0/0"
    port := dangerous_ports[_]
    rule.from_port <= port
    rule.to_port >= port
    result := {
        "resource": rule.address,
        "port": port,
        "message": sprintf("Security group rule '%s' exposes dangerous port %d to the internet (0.0.0.0/0)", [rule.address, port]),
    }
}

# Check for missing descriptions
missing_description[result] {
    sg := security_groups[_]
    not sg.description
    result := {
        "resource": sg.address,
        "name": sg.name,
        "message": sprintf("Security group '%s' is missing a description. Descriptions help with security audits", [sg.address]),
    }
}

missing_description[result] {
    sg := security_groups[_]
    sg.description == ""
    result := {
        "resource": sg.address,
        "name": sg.name,
        "message": sprintf("Security group '%s' has an empty description", [sg.address]),
    }
}

# Check for generic descriptions
generic_description[result] {
    sg := security_groups[_]
    generic_terms := ["managed by terraform", "security group", "default", "temp", "test"]
    term := generic_terms[_]
    contains(lower(sg.description), term)
    count(sg.description) < 50
    result := {
        "resource": sg.address,
        "name": sg.name,
        "description": sg.description,
        "message": sprintf("Security group '%s' has a generic description '%s'. Provide specific purpose and context", [sg.address, sg.description]),
    }
}

# Check for unrestricted egress
unrestricted_egress[result] {
    sg := security_groups[_]
    egress := sg.egress[_]
    egress.cidr_blocks[_] == "0.0.0.0/0"
    egress.from_port == 0
    egress.to_port == 0
    egress.protocol == "-1"
    # This is a warning, not a critical error
    result := {
        "resource": sg.address,
        "name": sg.name,
        "message": sprintf("Security group '%s' allows all outbound traffic. Consider restricting egress for better security posture", [sg.address]),
    }
}

# Check for IPv6 exposure with dangerous ports
ipv6_dangerous_exposure[result] {
    sg := security_groups[_]
    ingress := sg.ingress[_]
    ingress.ipv6_cidr_blocks[_] == "::/0"
    port := dangerous_ports[_]
    ingress.from_port <= port
    ingress.to_port >= port
    result := {
        "resource": sg.address,
        "name": sg.name,
        "port": port,
        "message": sprintf("Security group '%s' exposes dangerous port %d to IPv6 internet (::/0)", [sg.address, port]),
    }
}

# Main deny rules for critical violations
deny[msg] {
    violation := overly_permissive_ingress[_]
    msg := violation.message
}

deny[msg] {
    violation := dangerous_port_exposure[_]
    msg := violation.message
}

deny[msg] {
    violation := dangerous_port_in_rules[_]
    msg := violation.message
}

deny[msg] {
    violation := ipv6_dangerous_exposure[_]
    msg := violation.message
}

# Warnings for less critical issues
warn[msg] {
    violation := missing_description[_]
    msg := violation.message
}

warn[msg] {
    violation := generic_description[_]
    msg := violation.message
}

warn[msg] {
    violation := unrestricted_egress[_]
    msg := violation.message
}

# Helper rule for reporting
violations := array.concat(
    array.concat(
        array.concat(
            [v | v := overly_permissive_ingress[_]],
            [v | v := dangerous_port_exposure[_]]
        ),
        array.concat(
            [v | v := dangerous_port_in_rules[_]],
            [v | v := ipv6_dangerous_exposure[_]]
        )
    ),
    array.concat(
        array.concat(
            [v | v := missing_description[_]],
            [v | v := generic_description[_]]
        ),
        [v | v := unrestricted_egress[_]]
    )
)
