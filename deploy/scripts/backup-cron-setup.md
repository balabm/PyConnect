# Backup Cron Setup

1. Copy and edit the env file:
   ```bash
   sudo mkdir -p /var/backups/pondyconnect
   sudo cp /opt/pondyconnect/deploy/scripts/backup.env.example /opt/pondyconnect/deploy/scripts/backup.env
   sudo nano /opt/pondyconnect/deploy/scripts/backup.env
   ```

2. Make the script executable:
   ```bash
   sudo chmod +x /opt/pondyconnect/deploy/scripts/backup.sh
   ```

3. Add to crontab (runs every 12 hours):
   ```bash
   sudo crontab -e
   ```
   Add:
   ```
   0 */12 * * * /usr/bin/env bash -c 'set -a; source /opt/pondyconnect/deploy/scripts/backup.env; set +a; /opt/pondyconnect/deploy/scripts/backup.sh >> /var/log/pondyconnect_backup.log 2>&1'
   ```

4. Ensure AWS CLI is installed if uploading to S3:
   ```bash
   aws configure --profile default
   ```
