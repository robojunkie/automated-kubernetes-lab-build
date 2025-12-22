#!/bin/bash

# Prompt the user to optionally run the cleanup script
echo "Do you want to run cleanup.sh to remove any previous Kubernetes remnants? (yes/no)"
read -r user_input

if [[ "${user_input}" == "yes" ]]; then
    echo "Running cleanup.sh..."
    ./cleanup.sh || { echo "Cleanup script failed. Please check your setup."; exit 1; }
else
    echo "Skipping cleanup process."
fi

# Existing setup configuration prompts and structure...
echo "Welcome to the Kubernetes automated setup script. Please follow the instructions."
# Add other setup configurations here (existing content)
