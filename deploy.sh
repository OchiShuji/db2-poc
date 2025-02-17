#!/bin/bash

# Set up script variables
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
STACK_NAME="db2-poc-stack"

# Validate CloudFormation template
if aws cloudformation validate-template --template-body file://"$SCRIPT_DIR/cfn/public.yml"; then
    echo "Validation of template: successful."
    echo "Do you want to deploy the stack? [yes/no]"
    read -r deploy_stack

    if [[ "$deploy_stack" == "yes" ]]; then
        aws cloudformation deploy --stack-name "$STACK_NAME" --template-file "$SCRIPT_DIR/cfn/public.yml"
        aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME"
    fi
else
    echo "Validation of template: failed."
    exit 1
fi

# Get public IP of EC2 instance
public_ip=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" | jq -r '.Stacks[0].Outputs[0].OutputValue?')

if [[ -z "$public_ip" ]]; then
    echo "Failed to retrieve public IP."
    exit 1
fi

# Replace public_ip placeholder in Ansible configuration
echo $public_ip >> "$SCRIPT_DIR/ansible/inventory.ini"

# Run Ansible playbook
cd "$SCRIPT_DIR/ansible" || exit

if ansible-playbook -i inventory.ini site.yml --check; then
    echo "Validation of playbook: successful."
    echo "Do you want to set up a server? [yes/no]"
    
    read -r play_ansible
    if [[ "$play_ansible" == "yes" ]]; then
        ansible-playbook -i inventory.ini site.yml
    fi
else
    echo "Validation of playbook: failed."
    exit 1
fi
