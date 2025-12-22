# Automated Kubernetes Lab Build

## Overview
This project automates the creation of a Kubernetes lab environment for home or budget labs using a jump box. It sets up the Kubernetes cluster with master and worker nodes quickly and efficiently.

## Features
- Lab-agnostic: Can run in any environment (Proxmox, bare metal, etc.).
- Automates node setup, networking, and Kubernetes initialization.
- Prompts user input for lab specifics (IP addresses, subnet, etc.).

## How to Use
1. Clone this repository.
   ```bash
   git clone https://github.com/robojunkie/automated-kubernetes-lab-build.git
   ```
2. Navigate to the repo directory on your jump box.
3. Run the setup script:
   ```bash
   bash scripts/setup.sh
   ```