#!/bin/bash

################################################################################
# Automated Kubernetes Lab Build Script
# 
# Purpose: Automate the deployment of a production-grade Kubernetes cluster
#          in lab environments (Proxmox, bare metal, VirtualBox, etc.)
# 
# Usage:   bash build-lab.sh
#
# Author:  Your Name / Community Contributors
# License: MIT
################################################################################

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source helper modules
source "${SCRIPT_DIR}/helpers/logging.sh"
source "${SCRIPT_DIR}/helpers/error-handling.sh"
source "${SCRIPT_DIR}/helpers/ssh-utils.sh"
source "${SCRIPT_DIR}/modules/input-validation.sh"
source "${SCRIPT_DIR}/modules/networking-setup.sh"
source "${SCRIPT_DIR}/modules/k8s-deploy.sh"
source "${SCRIPT_DIR}/modules/addon-setup.sh"

# Global configuration
CLUSTER_NAME=""
MASTER_NODE=""
MASTER_IP=""
WORKER_NODES=()
WORKER_IPS=()
WORKER_COUNT=0
SUBNET=""
SUBNET_CIDR=""
PUBLIC_CONTAINERS=false
K8S_VERSION="1.28"
CNI_PLUGIN="calico"
KUBECONFIG_PATH=""
SSH_KEY=""
LOG_FILE="${PROJECT_ROOT}/deployment.log"
DRY_RUN=false

################################################################################
# Display Banner
################################################################################
display_banner() {
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║        Automated Kubernetes Lab Build Framework v1.0            ║
║                                                                  ║
║    Deploy production-grade Kubernetes in your home lab!         ║
║    Works with Proxmox, bare metal, VirtualBox, and more.       ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
EOF
}

################################################################################
# Display Usage
################################################################################
usage() {
    cat << EOF
Usage: bash build-lab.sh [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -d, --dry-run          Perform a dry run (don't make changes)
    -c, --config FILE      Use configuration file instead of interactive prompts
    --skip-validation      Skip network connectivity validation

EXAMPLES:
    bash build-lab.sh                    # Interactive mode
    bash build-lab.sh -c config.env      # Use config file
    bash build-lab.sh -d                 # Dry run mode

CONFIGURATION FILE FORMAT:
    See examples/example-config.env for sample configuration

EOF
    exit 0
}

################################################################################
# Parse Command Line Arguments
################################################################################
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -d|--dry-run)
                DRY_RUN=true
                log_info "Running in DRY-RUN mode. No changes will be made."
                shift
                ;;
            -c|--config)
                if [[ -z "${2:-}" ]]; then
                    log_error "Config file path required with --config"
                    exit 1
                fi
                if [[ ! -f "$2" ]]; then
                    log_error "Config file not found: $2"
                    exit 1
                fi
                # Source the config file
                source "$2"
                log_info "Loaded configuration from: $2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
}

################################################################################
# Collect User Input
################################################################################
collect_user_input() {
    log_info "=========================================="
    log_info "Kubernetes Cluster Configuration"
    log_info "=========================================="
    
    # Cluster name
    read -r -p "Enter cluster name [default: k8s-lab]: " CLUSTER_NAME
    CLUSTER_NAME="${CLUSTER_NAME:-k8s-lab}"
    
    log_info ""
    log_info "=========================================="
    log_info "Master Node Configuration"
    log_info "=========================================="
    
    # Master node
    read -r -p "Enter master node hostname or IP: " MASTER_NODE
    validate_hostname_or_ip "$MASTER_NODE"
    
    # Master IP (if hostname was provided)
    if is_hostname "$MASTER_NODE"; then
        read -r -p "Enter master node IP address: " MASTER_IP
        validate_ip "$MASTER_IP"
    else
        MASTER_IP="$MASTER_NODE"
        MASTER_NODE=$(get_hostname_from_ip "$MASTER_IP")
    fi
    
    log_info ""
    log_info "=========================================="
    log_info "Worker Node Configuration"
    log_info "=========================================="
    
    # Worker count
    read -r -p "Enter number of worker nodes [default: 2]: " WORKER_COUNT
    WORKER_COUNT="${WORKER_COUNT:-2}"
    validate_positive_integer "$WORKER_COUNT"
    
    # Collect worker nodes
    WORKER_NODES=()
    WORKER_IPS=()
    for i in $(seq 1 "$WORKER_COUNT"); do
        read -r -p "Enter hostname or IP of worker node $i: " WORKER_NODE
        validate_hostname_or_ip "$WORKER_NODE"
        
        if is_hostname "$WORKER_NODE"; then
            read -r -p "Enter IP address of worker node $i: " WORKER_IP
            validate_ip "$WORKER_IP"
        else
            WORKER_IP="$WORKER_NODE"
            WORKER_NODE=$(get_hostname_from_ip "$WORKER_IP")
        fi
        
        WORKER_NODES+=("$WORKER_NODE")
        WORKER_IPS+=("$WORKER_IP")
    done
    
    log_info ""
    log_info "=========================================="
    log_info "Network Configuration"
    log_info "=========================================="
    
    # Subnet configuration
    read -r -p "Enter subnet for cluster networking (e.g., 192.168.1.0/24): " SUBNET
    validate_subnet "$SUBNET"
    SUBNET_CIDR="$SUBNET"
    
    # Public container access
    log_info ""
    log_info "Container Access Options:"
    log_info "  • NO (default):  Containers are only reachable from within your lab network"
    log_info "  • YES:          Containers get public IPs via MetalLB (load balancer)"
    log_info ""
    read -r -p "Make containers publicly accessible? (yes/no) [default: no]: " PUBLIC_CONTAINERS_INPUT
    PUBLIC_CONTAINERS_INPUT="${PUBLIC_CONTAINERS_INPUT:-no}"
    
    if [[ "$PUBLIC_CONTAINERS_INPUT" =~ ^(yes|y|true)$ ]]; then
        PUBLIC_CONTAINERS=true
    fi
    
    log_info ""
    log_info "=========================================="
    log_info "Kubernetes Configuration"
    log_info "=========================================="
    
    # Kubernetes version
    read -r -p "Enter Kubernetes version [default: 1.28]: " K8S_VERSION
    K8S_VERSION="${K8S_VERSION:-1.28}"
    validate_k8s_version "$K8S_VERSION"
    
    # SSH Key Configuration
    echo -e "\n${BLUE}SSH Configuration:${NC}"
    read -r -p "Enter SSH key path (leave empty for default ~/.ssh/id_rsa): " SSH_KEY
    SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"
    
    if [[ -f "$SSH_KEY" ]]; then
        log_success "SSH key found: $SSH_KEY"
        export SSH_KEY
    else
        log_warning "SSH key not found at: $SSH_KEY"
        read -r -p "Continue without specifying key (use SSH agent/default)? [y/N]: " continue_without_key
        if [[ ! "$continue_without_key" =~ ^[Yy]$ ]]; then
            log_error "Please configure SSH key and try again"
            exit 1
        fi
        SSH_KEY=""
    fi
    
    # CNI plugin choice
    read -r -p "Select CNI plugin (calico|flannel|weave) [default: calico]: " CNI_PLUGIN
    CNI_PLUGIN="${CNI_PLUGIN:-calico}"
    validate_cni_plugin "$CNI_PLUGIN"
}

################################################################################
# Display Configuration Summary
################################################################################
display_config_summary() {
    log_info ""
    log_info "=========================================="
    log_info "Configuration Summary"
    log_info "=========================================="
    echo ""
    echo "Cluster Name:              $CLUSTER_NAME"
    echo "Master Node:               $MASTER_NODE ($MASTER_IP)"
    echo "Worker Nodes:              ${#WORKER_NODES[@]}"
    for i in "${!WORKER_NODES[@]}"; do
        echo "  - ${WORKER_NODES[$i]} (${WORKER_IPS[$i]})"
    done
    echo "Subnet (Pod CIDR):         $SUBNET_CIDR"
    echo "Public Container Access:   $([ "$PUBLIC_CONTAINERS" = true ] && echo "Yes" || echo "No")"
    echo "Kubernetes Version:        $K8S_VERSION"
    echo "CNI Plugin:                $CNI_PLUGIN"
    echo ""
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "MODE:                      DRY-RUN (no changes will be made)"
        echo ""
    fi
    
    read -r -p "Proceed with deployment? (yes/no): " PROCEED
    
    if [[ ! "$PROCEED" =~ ^(yes|y|true)$ ]]; then
        log_info "Deployment cancelled."
        exit 0
    fi
}

################################################################################
# Validate Prerequisites
################################################################################
validate_prerequisites() {
    log_info "Validating prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_warning "kubectl not found. It will be installed on the master node."
    fi
    
    # Check SSH connectivity to all nodes
    log_info "Checking SSH connectivity to nodes..."
    check_ssh_connectivity "$MASTER_IP"
    
    for WORKER_IP in "${WORKER_IPS[@]}"; do
        check_ssh_connectivity "$WORKER_IP"
    done
    
    log_success "All prerequisites validated successfully."
}

################################################################################
# Execute Deployment
################################################################################
execute_deployment() {
    log_info ""
    log_info "=========================================="
    log_info "Starting Kubernetes Cluster Deployment"
    log_info "=========================================="
    
    # Setup networking
    log_info "Setting up networking on all nodes..."
    setup_networking "$MASTER_IP" "${WORKER_IPS[@]}"
    
    # Deploy Kubernetes
    log_info "Deploying Kubernetes cluster..."
    deploy_kubernetes "$MASTER_NODE" "$MASTER_IP" "$K8S_VERSION"
    
    # Optional: Setup load balancing and ingress
    if [[ "$PUBLIC_CONTAINERS" == true ]]; then
        log_info "Setting up MetalLB for public container access..."
        setup_metallb "$SUBNET_CIDR" "$MASTER_IP"
    fi
    
    log_success "Kubernetes cluster deployment completed successfully!"
}

################################################################################
# Post-Deployment Configuration
################################################################################
post_deployment_config() {
    log_info ""
    log_info "=========================================="
    log_info "Post-Deployment Configuration"
    log_info "=========================================="
    
    # Get kubeconfig from master
    log_info "Retrieving kubeconfig from master node..."
    KUBECONFIG_PATH="${PROJECT_ROOT}/${CLUSTER_NAME}-kubeconfig.yaml"
    
    if [[ "$DRY_RUN" != true ]]; then
        ssh_execute "$MASTER_IP" "cat ~/.kube/config" > "$KUBECONFIG_PATH"
        chmod 600 "$KUBECONFIG_PATH"
        log_success "Kubeconfig saved to: $KUBECONFIG_PATH"
    fi
    
    # Display cluster info
    log_info ""
    log_info "=========================================="
    log_info "Cluster Information"
    log_info "=========================================="
    echo ""
    echo "To use your cluster, export the kubeconfig:"
    echo "  export KUBECONFIG=$KUBECONFIG_PATH"
    echo ""
    echo "Verify cluster status:"
    echo "  kubectl get nodes"
    echo "  kubectl get pods -A"
    echo ""
}

################################################################################
# Cleanup on Error
################################################################################
cleanup() {
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Deployment failed with exit code: $exit_code"
        log_info "Check the log file for details: $LOG_FILE"
    fi
    
    return $exit_code
}

################################################################################
# Main Execution
################################################################################
main() {
    # Setup error trap
    trap cleanup EXIT
    
    # Initialize logging
    init_logging "$LOG_FILE"
    
    # Display banner
    display_banner
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Collect user input (if not using config file)
    if [[ -z "$MASTER_NODE" ]]; then
        collect_user_input
    fi
    
    # Display configuration summary
    display_config_summary
    
    # Validate prerequisites
    validate_prerequisites
    
    # Execute deployment
    if [[ "$DRY_RUN" != true ]]; then
        execute_deployment
        post_deployment_config
    else
        log_info "DRY-RUN MODE: Deployment steps would be executed here"
        display_config_summary
    fi
    
    log_success ""
    log_success "=========================================="
    log_success "Deployment Process Complete"
    log_success "=========================================="
}

# Run main function
main "$@"
