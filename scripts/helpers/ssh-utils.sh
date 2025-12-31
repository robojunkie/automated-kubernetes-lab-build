#!/bin/bash

################################################################################
# SSH Utilities
# Provides SSH connectivity checks and remote command execution
################################################################################

################################################################################
# Check SSH connectivity to a host
################################################################################
check_ssh_connectivity() {
    local host=$1
    local timeout=${2:-10}
    
    log_debug "Checking SSH connectivity to: $host"
    
    if ssh -o ConnectTimeout=$timeout -o StrictHostKeyChecking=accept-new "$host" "echo 'SSH test'" &> /dev/null; then
        log_debug "SSH connectivity OK: $host"
        return 0
    else
        log_error "Cannot connect via SSH to: $host"
        return 1
    fi
}

################################################################################
# Execute command on remote host via SSH
################################################################################
ssh_execute() {
    local host=$1
    shift
    local command="$@"
    
    log_debug "Executing on $host: $command"
    
    ssh -o StrictHostKeyChecking=accept-new "$host" "$command"
}

################################################################################
# Copy file to remote host
################################################################################
scp_to_remote() {
    local local_file=$1
    local remote_host=$2
    local remote_path=$3
    
    log_debug "Copying to remote: $local_file -> $remote_host:$remote_path"
    
    scp -o StrictHostKeyChecking=accept-new "$local_file" "$remote_host:$remote_path"
}

################################################################################
# Copy file from remote host
################################################################################
scp_from_remote() {
    local remote_host=$1
    local remote_file=$2
    local local_path=$3
    
    log_debug "Copying from remote: $remote_host:$remote_file -> $local_path"
    
    scp -o StrictHostKeyChecking=accept-new "$remote_host:$remote_file" "$local_path"
}

################################################################################
# Check if host is reachable via ping
################################################################################
is_host_reachable() {
    local host=$1
    local timeout=${2:-5}
    
    if ping -c 1 -W "$timeout" "$host" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

################################################################################
# Wait for host to become reachable
################################################################################
wait_for_host() {
    local host=$1
    local max_attempts=${2:-30}
    local delay=${3:-2}
    local attempt=1
    
    log_info "Waiting for host to become reachable: $host"
    
    while [[ $attempt -le $max_attempts ]]; do
        if is_host_reachable "$host"; then
            log_success "Host is reachable: $host"
            return 0
        fi
        
        log_debug "Host not reachable yet. Attempt $attempt/$max_attempts"
        sleep "$delay"
        attempt=$((attempt + 1))
    done
    
    log_error "Host did not become reachable within timeout: $host"
    return 1
}
