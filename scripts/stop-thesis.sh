#!/bin/bash
echo "Stopping all MastersThesis EC2 instances..."

INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=MastersThesis" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text)

if [ -z "$INSTANCE_IDS" ]; then
  echo "No running instances found."
else
  aws ec2 stop-instances --instance-ids $INSTANCE_IDS
  echo "Stopping: $INSTANCE_IDS"
  echo "Waiting for confirmation..."
  aws ec2 wait instance-stopped --instance-ids $INSTANCE_IDS
  echo "✅ All instances stopped."
fi