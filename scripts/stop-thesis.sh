#!/bin/bash
echo "Stopping Pipeline 2 EC2 instances (Prod + Monitoring only)..."

INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=MastersThesis" \
            "Name=tag:Name,Values=thesis-prod-hybrid,thesis-monitoring" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text)

if [ -z "$INSTANCE_IDS" ]; then
  echo "No running Pipeline 2 instances found."
else
  aws ec2 stop-instances --instance-ids $INSTANCE_IDS
  echo "Stopping: $INSTANCE_IDS"
  echo "Waiting for confirmation..."
  aws ec2 wait instance-stopped --instance-ids $INSTANCE_IDS
  echo "✅ Pipeline 2 instances stopped. Jenkins (Pipeline 3's CI) left running."
fi