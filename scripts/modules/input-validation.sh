#!/bin/bash

################################################################################
# Input Validation Module
# Validates user input for hostnames, IPs, subnets, etc.
################################################################################

################################################################################
# Check if string is a valid hostname
################################################################################
is_hostname() {
    local hostname=$1
    # Simple check: if it contains a dot followed by numbers, it's likely an IP
    if [[ $hostname =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 1  # It's an IP, not a hostname
    fi
    return 0
}

################################################################################
# Check if string is a valid IP address
################################################################################
is_valid_ip() {
    local ip=$1
    
    # IPv4 check
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        local IFS=.
        local -a octets=($ip)
        for octet in "${octets[@]}"; do
            if [[ $octet -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi
    
    return 1
}

################################################################################
# Validate hostname or IP
################################################################################
validate_hostname_or_ip() {
    local input=$1
    
    if ! is_hostname "$input" && ! is_valid_ip "$input"; then
        log_error "Invalid hostname or IP address: $input"
        exit 1
    fi
}

################################################################################
# Validate IP address
################################################################################
validate_ip() {
    local ip=$1
    
    if ! is_valid_ip "$ip"; then
        log_error "Invalid IP address: $ip"
        exit 1
    fi
}

################################################################################
# Get hostname from IP (reverse DNS)
################################################################################
get_hostname_from_ip() {
    local ip=$1
    
    # Try reverse DNS lookup
    if command_exists dig; then
        dig +short -x "$ip" | sed 's/\.$//'
    elif command_exists host; then
        host "$ip" | awk '{print $NF}' | sed 's/\.$//'
    else
        # Fallback: just use the IP if no DNS tools available
        echo "$ip"
    fi
}

################################################################################
# Validate positive integer
################################################################################
validate_positive_integer() {
    local input=$1
    
    if ! [[ "$input" =~ ^[0-9]+$ ]] || [[ "$input" -le 0 ]]; then
        log_error "Invalid positive integer: $input"
        exit 1
    fi
}

################################################################################
# Validate subnet (CIDR notation)
################################################################################
validate_subnet() {
    local subnet=$1
    
    # Check CIDR notation (e.g., 192.168.1.0/24)
    if ! [[ $subnet =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        log_error "Invalid subnet format. Use CIDR notation (e.g., 192.168.1.0/24): $subnet"
        exit 1
    fi
    
    # Validate IP part
    local ip=$(echo "$subnet" | cut -d/ -f1)
    local prefix=$(echo "$subnet" | cut -d/ -f2)
    
    if ! is_valid_ip "$ip"; then
        log_error "Invalid IP in subnet: $ip"
        exit 1
    fi
    
    if ! [[ "$prefix" =~ ^[0-9]+$ ]] || [[ "$prefix" -lt 0 ]] || [[ "$prefix" -gt 32 ]]; then
        log_error "Invalid CIDR prefix length: $prefix"
        exit 1
    fi
}

################################################################################
# Validate Kubernetes version format
################################################################################
validate_k8s_version() {
    local version=$1
    
    # Should match pattern like 1.28, 1.27.x, etc.
    if ! [[ $version =~ ^1\.[0-9]{1,2}(\.[0-9]+)?$ ]]; then
        log_error "Invalid Kubernetes version format: $version"
        exit 1
    fi
}

################################################################################
# Validate CNI plugin
################################################################################
validate_cni_plugin() {
    local plugin=$1
    
    case "$plugin" in
        calico|flannel|weave)
            return 0
            ;;
        *)
            log_error "Unsupported CNI plugin: $plugin (supported: calico, flannel, weave)"
            exit 1
            ;;
    esac
}

################################################################################
# Confirm user action
################################################################################
confirm_action() {
    local prompt=$1
    local response
    
    read -r -p "$prompt (yes/no): " response
    
    if [[ "$response" =~ ^(yes|y|true)$ ]]; then
        return 0
    else
        return 1
    fi
}
