variable "project_name"       { type = string }
variable "subnet_id"          { type = string }
variable "security_group_id"  { type = string }
variable "key_name"           { type = string }
variable "ami_id"             { type = string }
variable "ecr_release_arn"  { type = string }
variable "ecr_snapshot_arn" { type = string }

resource "aws_iam_role" "jenkins" {
  name = "${var.project_name}-jenkins-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "jenkins_ecr" {
  name = "ECRAccess"
  role = aws_iam_role.jenkins.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:DescribeImages",
          "ecr:ListImages"
        ]
        Resource = [var.ecr_release_arn, var.ecr_snapshot_arn]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.project_name}-jenkins-profile"
  role = aws_iam_role.jenkins.name
}

resource "aws_iam_role" "prod_ecr" {
  name = "${var.project_name}-prod-ecr-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "prod_ecr_pull" {
  name = "ECRPullOnly"
  role = aws_iam_role.prod_ecr.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = [var.ecr_release_arn, var.ecr_snapshot_arn]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "prod_ecr" {
  name = "${var.project_name}-prod-ecr-profile"
  role = aws_iam_role.prod_ecr.name
}

resource "aws_iam_role" "monitoring_ecr" {
  name = "${var.project_name}-monitoring-ecr-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "monitoring_ecr_pull" {
  name = "ECRPullOnly"
  role = aws_iam_role.monitoring_ecr.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
      {
        Effect   = "Allow"
        Action   = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"]
        Resource = [var.ecr_release_arn, var.ecr_snapshot_arn]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "monitoring_ecr" {
  name = "${var.project_name}-monitoring-ecr-profile"
  role = aws_iam_role.monitoring_ecr.name
}

resource "aws_instance" "jenkins" {
  ami                    = var.ami_id
  instance_type          = "t3.medium"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = <<-USERDATA
    #!/bin/bash
    set -e
    exec > /var/log/user-data.log 2>&1
    echo "=== Starting Jenkins EC2 setup ==="

    apt-get update -y

    # Java 21
    apt-get install -y openjdk-21-jdk
    echo "Java 21: OK"

    # Maven + tools
    apt-get install -y maven git curl unzip
    echo "Maven: OK"

    # Docker
    apt-get install -y docker.io
    systemctl enable --now docker
    echo "Docker: OK"

    # AWS CLI for ECR pull
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/aws.zip
    unzip -q /tmp/aws.zip -d /tmp && /tmp/aws/install

    # Ansible
    apt-get install -y ansible python3-boto3 python3-botocore
    ansible-galaxy collection install community.docker
    echo "Ansible: OK"

    # Jenkins — import key via keyserver (most reliable on Ubuntu 22.04)
    gpg --keyserver hkps://keyserver.ubuntu.com \
      --recv-keys 7198F4B714ABFC68

    gpg --export 7198F4B714ABFC68 \
      | tee /usr/share/keyrings/jenkins-keyring.gpg > /dev/null

    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] https://pkg.jenkins.io/debian-stable binary/" \
      > /etc/apt/sources.list.d/jenkins.list

    apt-get update -y
    apt-get install -y jenkins
    usermod -aG docker jenkins
    systemctl enable --now jenkins
    echo "Jenkins: OK"

    # kubectl
    KUBECTL_VER=$(curl -sL https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/$KUBECTL_VER/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    echo "kubectl: OK"

    # Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo "Helm: OK"

    # ArgoCD CLI
    curl -sSL -o /usr/local/bin/argocd \
      https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    chmod +x /usr/local/bin/argocd
    echo "ArgoCD CLI: OK"

    # DORA log directory
    mkdir -p /var/log/dora
    chmod 777 /var/log/dora
    echo "commit_hash,commit_time,pipeline_start,build_end,deploy_start,deploy_end,status,pipeline" \
      > /var/log/dora/metrics.csv
    echo "incident_start,recovery_end,status,pipeline" \
      > /var/log/dora/mttr.csv

    echo "=== Jenkins EC2 setup COMPLETE ==="
  USERDATA

  tags = { Name = "${var.project_name}-jenkins" }
}

resource "aws_instance" "prod_hybrid" {
  ami                    = var.ami_id
  instance_type          = "t3.small"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.prod_ecr.name

  root_block_device {
    volume_size = 15
    volume_type = "gp3"
  }

  user_data = <<-USERDATA
    #!/bin/bash
    set -e
    exec > /var/log/user-data.log 2>&1
    echo "Starting Prod EC2 setup..."

    apt-get update -y
    apt-get install -y docker.io curl

    # AWS CLI for ECR authentication
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/aws.zip
    unzip -q /tmp/aws.zip -d /tmp && /tmp/aws/install

    systemctl enable --now docker

    apt-get install -y postgresql postgresql-contrib

    systemctl enable --now postgresql

    # Create database and user
    sudo -u postgres psql <<'SQL'
    CREATE DATABASE tire_testing;
    CREATE USER tire_user WITH ENCRYPTED PASSWORD 'thesis_pass';
    GRANT ALL PRIVILEGES ON DATABASE tire_testing TO tire_user;
    \c tire_testing
    ALTER SCHEMA public OWNER TO tire_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO tire_user;
    SQL

    # Allow Postgres to accept connections from Docker bridge network
    PG_VER=$(ls /etc/postgresql)
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/$PG_VER/main/postgresql.conf
    echo "host    tire_testing    tire_user    172.17.0.0/16    scram-sha-256" >> /etc/postgresql/$PG_VER/main/pg_hba.conf
    systemctl restart postgresql

    echo "PostgreSQL configured"

    NE_VER="1.7.0"
    wget -q "https://github.com/prometheus/node_exporter/releases/download/v$NE_VER/node_exporter-$NE_VER.linux-amd64.tar.gz"
    tar xvf "node_exporter-$NE_VER.linux-amd64.tar.gz"
    cp "node_exporter-$NE_VER.linux-amd64/node_exporter" /usr/local/bin/
    useradd --no-create-home --shell /bin/false node_exporter

    cat > /etc/systemd/system/node_exporter.service <<'SVC'
    [Unit]
    Description=Prometheus Node Exporter
    After=network.target
    [Service]
    User=node_exporter
    ExecStart=/usr/local/bin/node_exporter
    Restart=always
    [Install]
    WantedBy=multi-user.target
    SVC

    systemctl daemon-reload
    systemctl enable --now node_exporter

    echo "Prod EC2 setup COMPLETE"
  USERDATA

  tags = { Name = "${var.project_name}-prod-hybrid" }
}

resource "aws_instance" "monitoring" {
  ami                    = var.ami_id
  instance_type          = "t3.small"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.monitoring_ecr.name

  root_block_device {
    volume_size = 15
    volume_type = "gp3"
  }

  user_data = <<-USERDATA
    #!/bin/bash
    set -e
    exec > /var/log/user-data.log 2>&1
    echo "Starting Monitoring EC2 setup..."

    apt-get update -y
    apt-get install -y curl wget software-properties-common apt-transport-https unzip

    # Docker (for staging app container)
    apt-get install -y docker.io
    systemctl enable --now docker
    echo "Docker: OK"

    # AWS CLI for ECR pull
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/aws.zip
    unzip -q /tmp/aws.zip -d /tmp && /tmp/aws/install
    echo "AWS CLI: OK"

    # PostgreSQL (for staging DB)
    apt-get install -y postgresql postgresql-contrib
    systemctl enable --now postgresql

    sudo -u postgres psql <<'SQL'
    CREATE DATABASE tire_testing_staging;
    CREATE USER tire_user WITH ENCRYPTED PASSWORD 'thesis_pass';
    GRANT ALL PRIVILEGES ON DATABASE tire_testing_staging TO tire_user;
    \c tire_testing_staging
    ALTER SCHEMA public OWNER TO tire_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO tire_user;
    SQL

    PG_VER=$(ls /etc/postgresql)
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/$PG_VER/main/postgresql.conf
    echo "host    tire_testing_staging    tire_user    172.17.0.0/16    scram-sha-256" >> /etc/postgresql/$PG_VER/main/pg_hba.conf
    systemctl restart postgresql
    echo "PostgreSQL (staging) configured"

    # Prometheus
    PROM_VER="2.50.1"
    wget -q "https://github.com/prometheus/prometheus/releases/download/v$PROM_VER/prometheus-$PROM_VER.linux-amd64.tar.gz"
    tar xvf "prometheus-$PROM_VER.linux-amd64.tar.gz"
    cp "prometheus-$PROM_VER.linux-amd64/prometheus" /usr/local/bin/
    cp "prometheus-$PROM_VER.linux-amd64/promtool" /usr/local/bin/
    mkdir -p /etc/prometheus /var/lib/prometheus

    cat > /etc/prometheus/prometheus.yml <<'PROMCFG'
    global:
      scrape_interval: 15s
    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
    PROMCFG

    cat > /etc/systemd/system/prometheus.service <<'SVC'
    [Unit]
    Description=Prometheus
    After=network.target
    [Service]
    User=root
    ExecStart=/usr/local/bin/prometheus \
      --config.file=/etc/prometheus/prometheus.yml \
      --storage.tsdb.path=/var/lib/prometheus \
      --storage.tsdb.retention.time=30d \
      --web.enable-lifecycle
    Restart=always
    [Install]
    WantedBy=multi-user.target
    SVC

    systemctl daemon-reload
    systemctl enable --now prometheus

    # Grafana
    wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
    echo "deb https://packages.grafana.com/oss/deb stable main" \
      | tee /etc/apt/sources.list.d/grafana.list
    apt-get update -y
    apt-get install -y grafana
    systemctl enable --now grafana-server

    echo "Monitoring EC2 setup COMPLETE"
  USERDATA

  tags = { Name = "${var.project_name}-monitoring" }
}

output "jenkins_public_ip"      { value = aws_instance.jenkins.public_ip }
output "jenkins_private_ip"     { value = aws_instance.jenkins.private_ip }
output "prod_hybrid_public_ip"  { value = aws_instance.prod_hybrid.public_ip }
output "prod_hybrid_private_ip" { value = aws_instance.prod_hybrid.private_ip }
output "monitoring_public_ip"   { value = aws_instance.monitoring.public_ip }
output "monitoring_private_ip"  { value = aws_instance.monitoring.private_ip }