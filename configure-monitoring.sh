#!/bin/bash
# Run this AFTER terraform apply to inject real IPs into Prometheus config
# Usage: bash configure-monitoring.sh

set -e

MONITORING_IP=$(terraform output -raw monitoring_public_ip)
PROD_IP=$(terraform output -raw prod_private_ip)
JENKINS_IP=$(terraform output -raw jenkins_private_ip)

echo "Configuring Prometheus on: $MONITORING_IP"
echo "  Prod EC2 (scrape target): $PROD_IP"
echo "  Jenkins EC2:              $JENKINS_IP"

ssh -i ~/.ssh/thesis-key.pem \
    -o StrictHostKeyChecking=no \
    ubuntu@$MONITORING_IP \
    "sudo tee /etc/prometheus/prometheus.yml > /dev/null << 'PROMEOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:

  # System metrics from Prod EC2 (CPU, RAM, disk, network)
  - job_name: 'node-exporter-prod'
    static_configs:
      - targets: ['${PROD_IP}:9100']
        labels:
          pipeline: 'hybrid'
          role: 'production-server'

  # Spring Boot Actuator metrics (JVM, HTTP, DB pool, custom)
  # Port 8081 matches your management.server.port setting
  - job_name: 'tire-testing-app'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['${PROD_IP}:8081']
        labels:
          pipeline: 'hybrid'
          app: 'tire-testing'

  # Jenkins build metrics (install Prometheus plugin in Jenkins)
  - job_name: 'jenkins'
    metrics_path: '/prometheus'
    static_configs:
      - targets: ['${JENKINS_IP}:8080']
        labels:
          role: 'ci-server'

  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
PROMEOF
sudo systemctl reload prometheus
echo 'Prometheus reconfigured'"

echo ""
echo "Done. Access your monitoring:"
echo "  Grafana:    http://$MONITORING_IP:3000  (admin / admin)"
echo "  Prometheus: http://$MONITORING_IP:9090"
echo ""
echo "Next steps in Grafana:"
echo "  1. Add Prometheus data source: http://localhost:9090"
echo "  2. Import dashboard 1860  (Node Exporter Full)"
echo "  3. Import dashboard 9964  (Spring Boot Statistics)"
echo "  4. Import dashboard 12464 (Jenkins Performance)"
