# PY Connect — Day 1 Server Architecture Deployment Strategy

## Current Infrastructure
- **EC2**: Single t-series instance (16.16.120.192, Ubuntu 24.04)
- **Backend**: Docker container (`pondyconnect_api`) on port 5000
- **Database**: PostgreSQL on AWS RDS
- **Cache**: Redis container on the EC2 instance
- **Reverse Proxy**: Nginx with TLS (Let's Encrypt)
- **Domain**: pyconnect.run.place

## Target: Production-Grade Auto-Scaling Architecture

### Tier 1: Immediate (Before 1,000 orders/day)

#### 1. Database — RDS Upgrade
- **Current**: Single RDS PostgreSQL instance
- **Action**: Enable automated backups (7-day retention), enable Multi-AZ standby
- **Instance**: Upgrade to `db.t3.medium` (4GB RAM) if currently on micro
- **Storage**: Provisioned IOPS SSD, 20GB initial with auto-scaling to 100GB
- **Connection pooling**: Enable RDS Proxy or PgBouncer to handle connection spikes
- **Monitoring**: Enable RDS Enhanced Monitoring + Performance Insights

#### 2. Backend — Docker Compose → ECS Fargate
- **Current**: Single Docker container on EC2
- **Action**: Migrate to ECS Fargate (serverless containers)
- **Auto-scaling**: 2-10 tasks based on CPU > 70%
- **Load balancer**: Application Load Balancer (ALB) in front of ECS
- **Health checks**: ALB health check on `/health` endpoint (30s interval)
- **Why Fargate over EC2**: No server management, pay-per-second, automatic scaling

#### 3. Redis — ElastiCache
- **Current**: Redis container on EC2 (single point of failure)
- **Action**: Migrate to ElastiCache for Redis (cache.t3.micro)
- **Why**: Managed failover, automated backups, no maintenance windows
- **Use cases**: Rate limiting, OTP windows, session cache, SignalR backplane

#### 4. Nginx → ALB + CloudFront
- **Current**: Nginx on EC2 for TLS termination and static file serving
- **Action**:
  - Replace Nginx with AWS ALB for API traffic (TLS via ACM certificates)
  - Use CloudFront for static web apps (Admin, Partner) + `.well-known/` files
  - CloudFront provides: edge caching, DDoS protection, global CDN

#### 5. SignalR Backplane
- **Current**: Single server SignalR (breaks when scaling to multiple instances)
- **Action**: Configure Redis backplane for SignalR
  - Add `services.AddSignalR().AddStackExchangeRedis(redisConnectionString)`
  - All SignalR messages broadcast across all ECS tasks via Redis pub/sub

### Tier 2: Growth (1,000-10,000 orders/day)

#### 6. API Gateway
- **Add**: AWS API Gateway in front of ALB
- **Benefits**: Request throttling, API key management, request/response transformation
- **WAF**: Attach AWS WAF for SQL injection, XSS, and bot protection

#### 7. Read Replicas
- **Add**: PostgreSQL read replica for reporting/admin queries
- **Routing**: Write queries → primary, read queries → replica
- **Admin dashboard** and analytics queries hit the replica

#### 8. SQS for Async Workflows
- **Migrate**: Background workers (FraudDetectionWorker, PayoutWorker) to SQS-triggered Lambda functions
- **Benefits**: Decoupled processing, automatic retries, dead-letter queues

#### 9. S3 for Document Storage
- **Current**: Mock storage (no real blob storage)
- **Action**: S3 bucket for KYC documents, order photos, dispute evidence
- **Lifecycle**: Move documents to Glacier after 90 days
- **Pre-signed URLs**: Generate time-limited upload/download URLs

### Tier 3: Scale (10,000+ orders/day)

#### 10. Database Sharding
- Shard by geography (Pondicherry cluster, future city clusters)
- Use PostgreSQL declarative partitioning for large tables (orders, rides)

#### 11. Elasticsearch
- Replace PostgreSQL full-text search with Elasticsearch
- Power venue/restaurant search with fuzzy matching, autocomplete

#### 12. Multi-Region
- Active-active deployment across 2 AWS regions
- Route53 latency-based routing

## Backup & Disaster Recovery

### Database Backups
- **Automated**: RDS automated backups (7-day retention, 5-minute point-in-time recovery)
- **Manual**: Weekly snapshot, monthly snapshot retained 12 months
- **Cross-region**: Copy snapshots to secondary region daily

### Application Backups
- **Container images**: Docker Hub / ECR with image tagging (never overwrite `:latest`)
- **Configuration**: Store env vars in AWS Systems Manager Parameter Store (not in Git)
- **Secrets**: Use AWS Secrets Manager for JWT keys, Razorpay keys, DB credentials

### Disaster Recovery Plan
- **RTO (Recovery Time Objective)**: 30 minutes
- **RPO (Recovery Point Objective)**: 5 minutes (RDS PITR)
- **Runbook**: 
  1. Promote read replica to primary (if primary fails)
  2. Deploy ECS tasks to secondary region
  3. Update Route53 health check to failover

## Monitoring & Alerting

### CloudWatch
- **Alarms**: CPU > 80%, Memory > 85%, 5xx error rate > 1%, DB connections > 80%
- **Dashboards**: API latency, order throughput, active drivers, SignalR connections
- **Logs**: Structured JSON logging from .NET → CloudWatch Logs → Insights queries

### Alerting
- **Critical**: SNS → SMS to on-call engineer
- **Warning**: SNS → Slack webhook
- **Info**: CloudWatch dashboard only

## Cost Estimate (Monthly)

| Service | Tier 1 | Tier 2 |
|---------|--------|--------|
| ECS Fargate (2 tasks) | $35 | $70 |
| ALB | $18 | $18 |
| RDS PostgreSQL | $25 | $80 |
| ElastiCache Redis | $12 | $25 |
| CloudFront | $5 | $20 |
| S3 | $2 | $10 |
| Route53 | $1 | $1 |
| **Total** | **~$98/mo** | **~$224/mo** |

## Migration Steps (Zero Downtime)

1. **Provision new infrastructure** (ECS, ALB, ElastiCache) alongside current EC2
2. **Deploy backend to ECS** with the same RDS database
3. **Test** the new ALB endpoint with a small percentage of traffic (weighted routing)
4. **Switch DNS** (Route53) from EC2 IP to ALB when confident
5. **Decommission** the EC2 instance after 7 days of stable operation
6. **Enable auto-scaling** policies once traffic is routed through ALB

## Security Hardening

- **VPC**: Private subnets for RDS, ElastiCache, ECS tasks
- **Security groups**: Least-privilege rules (ALB → ECS → RDS only)
- **TLS**: All inter-service communication over TLS
- **WAF**: SQL injection, XSS, rate limiting rules
- **IAM**: Separate roles for ECS tasks, Lambda functions, CI/CD
- **Secrets rotation**: JWT signing key rotated every 90 days
