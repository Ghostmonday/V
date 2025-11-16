#!/bin/bash
set -e

# Update system
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# Install Docker
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Install Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Install Git
apt-get install -y git

# Install AWS CLI
apt-get install -y awscli

# Install PostgreSQL client (for migrations)
apt-get install -y postgresql-client

# Create vibez user
useradd -m -s /bin/bash vibez || true
usermod -aG docker vibez

# Clone repository
cd /home/vibez
if [ ! -d "VibeZ" ]; then
  sudo -u vibez git clone ${github_repo} VibeZ
fi

cd VibeZ
sudo -u vibez git pull || true

# Create .env file
cat > /home/vibez/VibeZ/.env <<ENVEOF
# Database
NEXT_PUBLIC_SUPABASE_URL=postgresql://${db_user}:${db_password}@${db_host}/${db_name}
SUPABASE_SERVICE_ROLE_KEY=${db_password}

# Redis
REDIS_HOST=${redis_instance_private_ip}
REDIS_URL=redis://${redis_instance_private_ip}:${redis_port}

# AWS S3
AWS_S3_BUCKET=${s3_bucket}
AWS_REGION=${aws_region}

# Application
NODE_ENV=${environment}
PORT=3000
JWT_SECRET=$(openssl rand -hex 32)

# DeepSeek (set via AWS Systems Manager Parameter Store or Secrets Manager)
# DEEPSEEK_API_KEY=your-key-here
ENVEOF

# Install dependencies and build
cd /home/vibez/VibeZ
sudo -u vibez npm ci
sudo -u vibez npm run build

# Create systemd service
cat > /etc/systemd/system/vibez.service <<EOF
[Unit]
Description=VibeZ API Server
After=network.target docker.service

[Service]
Type=simple
User=vibez
WorkingDirectory=/home/vibez/VibeZ
Environment=NODE_ENV=${environment}
EnvironmentFile=/home/vibez/VibeZ/.env
ExecStart=/usr/bin/node dist/server/index.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
systemctl daemon-reload
systemctl enable vibez
systemctl start vibez

# Install CloudWatch agent (optional)
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E amazon-cloudwatch-agent.deb || true

# Log completion
echo "VibeZ deployment completed at $(date)" >> /var/log/vibez-deploy.log

