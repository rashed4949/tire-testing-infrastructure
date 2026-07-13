#!/bin/bash
echo "Starting Pipeline 2 EC2 instances (Prod + Monitoring only)..."

INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=MastersThesis" \
            "Name=tag:Name,Values=thesis-prod-hybrid,thesis-monitoring" \
            "Name=instance-state-name,Values=stopped" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text)

if [ -z "$INSTANCE_IDS" ]; then
  echo "No stopped Pipeline 2 instances found."
else
  aws ec2 start-instances --instance-ids $INSTANCE_IDS
  echo "Starting: $INSTANCE_IDS"
  echo "Waiting until running..."
  aws ec2 wait instance-running --instance-ids $INSTANCE_IDS
  echo "✅ Pipeline 2 instances running. Fetching fresh IPs..."
  aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=MastersThesis" \
              "Name=tag:Name,Values=thesis-prod-hybrid,thesis-monitoring" \
              "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].[Tags[?Key=='Name']|[0].Value, InstanceId, PublicIpAddress]" \
    --output table
fi