#!/bin/bash

################################################################################
# Error Handling Utilities
# Provides error handling, retries, and graceful failure mechanisms
################################################################################

################################################################################
# Retry a command with exponential backoff
################################################################################
retry_with_backoff() {
    local max_attempts=$1
    local delay=$2
    shift 2
    local command="$@"
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log_debug "Attempt $attempt of $max_attempts: $command"
        
        if eval "$command"; then
            return 0
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            log_warning "Command failed. Retrying in ${delay}s... (attempt $attempt/$max_attempts)"
            sleep "$delay"
            delay=$((delay * 2))  # Exponential backoff
        fi
        
        attempt=$((attempt + 1))
    done
    
    log_error "Command failed after $max_attempts attempts: $command"
    return 1
}

################################################################################
# Check if command exists
################################################################################
command_exists() {
    command -v "$1" &> /dev/null
}

################################################################################
# Assert that a command exists
################################################################################
assert_command_exists() {
    if ! command_exists "$1"; then
        log_error "Required command not found: $1"
        exit 1
    fi
}

################################################################################
# Assert that a file exists
################################################################################
assert_file_exists() {
    if [[ ! -f "$1" ]]; then
        log_error "Required file not found: $1"
        exit 1
    fi
}

################################################################################
# Assert that a directory exists
################################################################################
assert_dir_exists() {
    if [[ ! -d "$1" ]]; then
        log_error "Required directory not found: $1"
        exit 1
    fi
}

################################################################################
# Check if running as root
################################################################################
assert_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

################################################################################
# Check if running as non-root
################################################################################
assert_not_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script must NOT be run as root"
        exit 1
    fi
}

################################################################################
# Handle script exit
################################################################################
handle_exit() {
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "Script completed successfully"
    else
        log_error "Script failed with exit code: $exit_code"
    fi
    
    return $exit_code
}
