#!/bin/bash

################################################################################
# Logging Utilities
# Provides colored log output and file logging
################################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Log file
LOG_FILE=""

################################################################################
# Initialize logging
################################################################################
init_logging() {
    if [[ -n "$1" ]]; then
        LOG_FILE="$1"
        touch "$LOG_FILE"
    fi
}

################################################################################
# Log to file (if LOG_FILE is set)
################################################################################
log_to_file() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local level=$1
    shift
    local message="$@"
    
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
}

################################################################################
# Log INFO message
################################################################################
log_info() {
    local message="$@"
    echo -e "${BLUE}[INFO]${NC} $message"
    log_to_file "INFO" "$message"
}

################################################################################
# Log SUCCESS message
################################################################################
log_success() {
    local message="$@"
    echo -e "${GREEN}[SUCCESS]${NC} $message"
    log_to_file "SUCCESS" "$message"
}

################################################################################
# Log WARNING message
################################################################################
log_warning() {
    local message="$@"
    echo -e "${YELLOW}[WARNING]${NC} $message"
    log_to_file "WARNING" "$message"
}

################################################################################
# Log ERROR message
################################################################################
log_error() {
    local message="$@"
    echo -e "${RED}[ERROR]${NC} $message" >&2
    log_to_file "ERROR" "$message"
}

################################################################################
# Log DEBUG message (only if DEBUG is set)
################################################################################
log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        local message="$@"
        echo -e "${CYAN}[DEBUG]${NC} $message"
        log_to_file "DEBUG" "$message"
    fi
}
