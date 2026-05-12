# Kubernetes Resources

This directory contains Kubernetes manifests for CloudPollPro's core services deployed on EKS.

## Summary

CloudPollPro is a microservices-based voting application running on Amazon EKS. The deployment consists of three application services (vote, worker, result) backed by Redis for real-time voting data and PostgreSQL (RDS) for persistent results storage.

**Key Infrastructure Components:**
- **Storage**: EBS CSI Driver for dynamic persistent volume provisioning (gp3 encrypted volumes)
- **Secrets Management**: External Secrets Operator syncing credentials from AWS Secrets Manager
- **Data Layer**: Redis cluster (primary-replica) for session/cache, RDS PostgreSQL for persistent storage
- **Ingress**: AWS Load Balancer Controller provisioning internet-facing ALBs for public access

**Application Stack:**
- **vote**: Python/Flask frontend (3 replicas) - users cast votes
- **worker**: .NET Core background processor (1 replica) - consumes votes from Redis and persists to PostgreSQL
- **result**: Node.js dashboard (2 replicas) - displays real-time results from PostgreSQL

All components follow cloud-native patterns with proper health checks, resource limits, rolling updates, and IRSA-based AWS authentication.

## Architecture Overview

### 1. Infrastructure & Data Layer

This diagram shows the foundational components: storage, data services, and secrets management.

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'primaryColor':'#e5e7eb','primaryTextColor':'#111827','primaryBorderColor':'#9ca3af','lineColor':'#111827','secondaryColor':'#d1d5db','tertiaryColor':'#f3f4f6','edgeLabelBackground':'#ffffff','mainBkg':'#f5f5f4','nodeBorder':'#9ca3af','background':'#f5f5f4','clusterBkg':'transparent'},'themeCSS':'.node rect, .node circle, .node ellipse, .node polygon, .node path { filter: none !important; box-shadow: none !important; } .cluster rect { filter: none !important; box-shadow: none !important; } svg { background-color: #f5f5f4 !important; } .cluster-label { background-color: #ffffff !important; padding: 6px 12px !important; border-radius: 4px !important; font-size: 16px !important; font-weight: 700 !important; box-shadow: 0 1px 3px rgba(0,0,0,0.12) !important; border: 1px solid #d1d5db !important; } .edgePath, .edgePath path, .flowchart-link { z-index: 1 !important; }'}}%%
graph TB
    subgraph AWS["☁️ AWS Services"]
        direction TB
        SM[("🔐 Secrets Manager<br/><b>cloudpollpro-rds</b>")]
        EBS[("💾 EBS Volumes<br/><i>gp3 encrypted</i>")]
        RDS[("🗄️ RDS PostgreSQL<br/><b>cloudpollpro-postgres</b>")]
    end

    subgraph K8S["⎈ EKS Cluster"]
        direction TB
        
        subgraph NS1["📦 kube-system"]
            CSI{{"🔌 EBS CSI Driver<br/><i>IRSA enabled</i>"}}
        end
        
        subgraph NS2["📦 external-secrets-system"]
            ESO{{"🔄 External Secrets Operator<br/><i>IRSA enabled</i>"}}
        end
        
        subgraph NS3["📦 default namespace"]
            direction TB
            
            SC["📂 StorageClass<br/><b>ebs-gp3</b>"]
            
            subgraph REDIS["🗂️ Redis Cluster"]
                direction TB
                RP("🔴 Primary<br/>1 pod<br/>5Gi PVC")
                RR("🔴 Replicas<br/>2 pods<br/>5Gi PVC each")
                RR -.->|replicates| RP
            end
            
            subgraph REDISSVC["🌐 Redis Services"]
                direction LR
                SvcP(["redis-primary:6379<br/><i>writes</i>"])
                SvcR(["redis-replica:6379<br/><i>reads</i>"])
            end
            
            subgraph SEC["🔑 Secrets Management"]
                direction TB
                CSS["ClusterSecretStore<br/><i>aws-secrets-manager</i>"]
                ES["ExternalSecret<br/><i>rds-credentials</i>"]
                K8S_SEC[/"K8s Secret<br/><b>rds-credentials</b>"/]
            end
        end
    end

    %% AWS to K8s infrastructure
    CSI -.->|provisions| EBS
    ESO -.->|fetches| SM
    
    %% Storage flow
    SC -->|uses| CSI
    RP -->|requests PVC| SC
    RR -->|requests PVC| SC
    
    %% Redis services
    SvcP -->|routes| RP
    SvcR -->|routes| RR
    
    %% Secrets sync flow
    CSS -->|uses| ESO
    ES -->|watches| CSS
    ES -->|creates| K8S_SEC
    
    %% RDS connection available
    K8S_SEC -.->|provides credentials for| RDS

    %% Styling
    classDef awsStyle fill:#F97316,stroke:#EA580C,stroke-width:2px,color:#fff
    classDef operatorStyle fill:#3B82F6,stroke:#2563EB,stroke-width:2px,color:#fff
    classDef workloadStyle fill:#EF4444,stroke:#DC2626,stroke-width:2px,color:#fff
    classDef serviceStyle fill:#F59E0B,stroke:#D97706,stroke-width:2px,color:#fff
    classDef secretStyle fill:#10B981,stroke:#059669,stroke-width:2px,color:#fff
    classDef configStyle fill:#6366F1,stroke:#4F46E5,stroke-width:2px,color:#fff
    
    class SM,EBS,RDS awsStyle
    class CSI,ESO operatorStyle
    class RP,RR workloadStyle
    class SvcP,SvcR serviceStyle
    class K8S_SEC secretStyle
    class SC,CSS,ES configStyle
    
    style AWS fill:#e5e7eb,stroke:#4b5563,stroke-width:2px,stroke-dasharray: 5 5
    style K8S fill:#d1d5db,stroke:#4b5563,stroke-width:2px,stroke-dasharray: 5 5
    style NS1 fill:#f3f4f6,stroke:#6b7280,stroke-width:1px,stroke-dasharray: 5 5
    style NS2 fill:#f3f4f6,stroke:#6b7280,stroke-width:1px,stroke-dasharray: 5 5
    style NS3 fill:#f3f4f6,stroke:#6b7280,stroke-width:1px,stroke-dasharray: 5 5
    style REDIS fill:#ffffff,stroke:#6b7280,stroke-width:1px,stroke-dasharray: 5 5
    style REDISSVC fill:#ffffff,stroke:#6b7280,stroke-width:1px,stroke-dasharray: 5 5
    style SEC fill:#ffffff,stroke:#6b7280,stroke-width:1px,stroke-dasharray: 5 5
```

### 2. Application & Traffic Flow

This diagram shows how user requests flow through the application stack.

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'primaryColor':'#e5e7eb','primaryTextColor':'#111827','primaryBorderColor':'#9ca3af','lineColor':'#111827','secondaryColor':'#d1d5db','tertiaryColor':'#f3f4f6','edgeLabelBackground':'#ffffff','mainBkg':'#f5f5f4','nodeBorder':'#9ca3af','background':'#f5f5f4','clusterBkg':'transparent'},'themeCSS':'.node rect, .node circle, .node ellipse, .node polygon, .node path { filter: none !important; box-shadow: none !important; } .cluster rect { filter: none !important; box-shadow: none !important; } svg { background-color: #f5f5f4 !important; } .cluster-label { background-color: #ffffff !important; padding: 6px 12px !important; border-radius: 4px !important; font-size: 16px !important; font-weight: 700 !important; box-shadow: 0 1px 3px rgba(0,0,0,0.12) !important; border: 1px solid #d1d5db !important; } .edgePath, .edgePath path, .flowchart-link { z-index: 1 !important; }'}}%%
graph TB
    USERS["👥 Users<br/><i>Internet</i>"]
    ALB["⚖️ Application Load Balancer<br/><i>AWS</i>"]
    RDS[("🗄️ RDS PostgreSQL<br/><i>AWS</i>")]

    subgraph K8S["⎈ EKS Cluster"]
        direction TB
        
        subgraph NS1["📦 kube-system"]
            ALBC{{"🎯 ALB Controller<br/><i>manages ALB</i>"}}
        end
        
        subgraph NS3["📦 default namespace"]
            direction TB
            
            subgraph ING["🌐 Ingress"]
                direction LR
                VING["vote-ingress"]
                RING["result-ingress"]
            end
            
            subgraph SVC["🌐 Services"]
                direction LR
                VOTESVC(["vote:80"])
                RESULTSVC(["result:80"])
                REDISSVC(["redis-primary:6379"])
            end
            
            subgraph APPS["🚀 Applications"]
                direction TB
                VOTE("🗳️ vote<br/>3 pods<br/><i>Python</i>")
                RESULT("📊 result<br/>2 pods<br/><i>Node.js</i>")
                WORKER("⚙️ worker<br/>1 pod<br/><i>.NET</i>")
            end
            
            SEC[/"🔑 rds-credentials<br/><i>Secret</i>"/]
        end
    end

    %% User traffic flow
    USERS -->|1. HTTP request| ALB
    ALB -->|2. route /vote| VING
    ALB -->|2. route /results| RING
    
    %% Ingress watched by ALB controller
    ALBC -.->|provisions & updates| ALB
    VING -.->|watched by| ALBC
    RING -.->|watched by| ALBC
    
    %% Ingress to Services
    VING -->|3. target| VOTESVC
    RING -->|3. target| RESULTSVC
    
    %% Services to Pods
    VOTESVC -->|4. route| VOTE
    RESULTSVC -->|4. route| RESULT
    
    %% Application data flow
    VOTE -->|5. write votes| REDISSVC
    WORKER -->|6. read votes| REDISSVC
    WORKER -->|7. persist results| RDS
    RESULT -->|8. read results| RDS
    
    %% Secret usage
    SEC -.->|provides DB creds| WORKER
    SEC -.->|provides DB creds| RESULT

    %% Styling
    classDef awsStyle fill:#F97316,stroke:#EA580C,stroke-width:2px,color:#fff
    classDef operatorStyle fill:#3B82F6,stroke:#2563EB,stroke-width:2px,color:#fff
    classDef workloadStyle fill:#EF4444,stroke:#DC2626,stroke-width:2px,color:#fff
    classDef serviceStyle fill:#F59E0B,stroke:#D97706,stroke-width:2px,color:#fff
    classDef ingressStyle fill:#EC4899,stroke:#DB2777,stroke-width:2px,color:#fff
    classDef userStyle fill:#14B8A6,stroke:#0D9488,stroke-width:2px,color:#fff
    classDef secretStyle fill:#10B981,stroke:#059669,stroke-width:2px,color:#fff
    
    class ALB,RDS awsStyle
    class ALBC operatorStyle
    class VOTE,WORKER,RESULT workloadStyle
    class VOTESVC,RESULTSVC,REDISSVC serviceStyle
    class VING,RING ingressStyle
    class USERS userStyle
    class SEC secretStyle
    
    style K8S fill:#d1d5db,stroke:#4b5563,stroke-width:2px,stroke-dasharray: 5 5
    style NS1 fill:#f3f4f6,stroke:#6b7280,stroke-width:1px,stroke-dasharray: 5 5
    style NS3 fill:#f3f4f6,stroke:#6b7280,stroke-width:1px,stroke-dasharray: 5 5
    style ING fill:#ffffff,stroke:#6b7280,stroke-width:1px,stroke-dasharray: 5 5
    style SVC fill:#ffffff,stroke:#6b7280,stroke-width:1px,stroke-dasharray: 5 5
    style APPS fill:#ffffff,stroke:#6b7280,stroke-width:1px,stroke-dasharray: 5 5
```

**Color Legend:**
- 🟠 **AWS Services**: Managed AWS resources (ALB, Secrets Manager, EBS, RDS)
- 🔵 **Operators**: Kubernetes controllers (CSI Driver, External Secrets, ALB Controller)
- 🔴 **Workloads**: Application and database pods
- 🟡 **Services**: Kubernetes service discovery
- 🟢 **Secrets**: Sensitive credentials
- 🟣 **Config**: StorageClass, ClusterSecretStore, ExternalSecret
- 🟣 **Ingress**: Ingress resources
- 🟢 **Users**: External traffic

## Components

### 1. Storage (`storage/`)

**EBS CSI Driver Integration**
- **StorageClass**: `ebs-gp3` (default)
  - Provisioner: `ebs.csi.aws.com`
  - Volume type: gp3 (encrypted)
  - Binding mode: WaitForFirstConsumer (topology-aware)
  - Allows volume expansion

**Why**: Dynamic provisioning of persistent EBS volumes for stateful workloads.

### 2. Redis (`redis/`)

**Primary-Replica Architecture**
- **Primary StatefulSet**: 1 replica
  - Handles all write operations
  - AOF (Append-Only File) + RDB snapshots for persistence
  - 5Gi persistent volume per pod
  - Service: `redis-primary.default.svc.cluster.local:6379`

- **Replica StatefulSet**: 2 replicas
  - Handles read operations (load balancing)
  - Replicates from primary via stable DNS
  - 5Gi persistent volume per pod
  - Service: `redis-replica.default.svc.cluster.local:6379`

- **Headless Service**: `redis-headless`
  - Provides stable DNS for StatefulSet pods
  - Example: `redis-primary-0.redis-headless.default.svc.cluster.local`

**Configuration** (`configmap.yaml`):
- Persistence: AOF enabled + RDB snapshots (900s/1 key, 300s/10 keys, 60s/10000 keys)
- No authentication (dev environment)
- Max memory policy: noeviction

**Why**: Session storage, caching, real-time features for CloudPollPro application.

### 3. Secrets Management (`secrets/`)

**External Secrets Operator Integration**
- **ClusterSecretStore**: `aws-secrets-manager`
  - Provider: AWS Secrets Manager (eu-west-3)
  - Authentication: IRSA (IAM Roles for Service Accounts)
  - Scope: Cluster-wide, usable from any namespace

- **ExternalSecret**: `rds-credentials`
  - Source: `cloudpollpro-rds-*` in AWS Secrets Manager
  - Target: Kubernetes Secret `rds-credentials`
  - Refresh interval: 1 hour
  - Synced fields: username, password, host, port, dbname

**Why**: Secure credential management without storing secrets in git. Automatic sync from AWS Secrets Manager to Kubernetes.

### 4. Applications (`apps/`)

**CloudPollPro Microservices**

- **vote** (`apps/vote/`)
  - **Deployment**: 3 replicas with pod anti-affinity across zones
  - **Image**: `058264398399.dkr.ecr.eu-west-3.amazonaws.com/cloudpollpro-vote:latest`
  - **Language**: Python/Flask
  - **Purpose**: Frontend for voting (Cats vs Dogs)
  - **Connections**: Writes votes to `redis-primary:6379`
  - **Service**: ClusterIP on port 80
  - **Resources**: 256Mi memory, 200m CPU requests
  - **Strategy**: RollingUpdate (maxSurge:1, maxUnavailable:0)

- **worker** (`apps/worker/`)
  - **Deployment**: 1 replica
  - **Image**: `058264398399.dkr.ecr.eu-west-3.amazonaws.com/cloudpollpro-worker:latest`
  - **Language**: .NET Core
  - **Purpose**: Background processor consuming votes from Redis and persisting to PostgreSQL
  - **Connections**: 
    - Reads from `redis-primary:6379`
    - Writes to RDS PostgreSQL (via `rds-credentials` secret)
  - **Strategy**: RollingUpdate (maxSurge:1, maxUnavailable:0)

- **result** (`apps/result/`)
  - **Deployment**: 2 replicas
  - **Image**: `058264398399.dkr.ecr.eu-west-3.amazonaws.com/cloudpollpro-result:latest`
  - **Language**: Node.js
  - **Purpose**: Real-time results dashboard
  - **Connections**: Reads from RDS PostgreSQL (via `rds-credentials` secret)
  - **Service**: ClusterIP on port 80
  - **Environment**: Uses `PG_HOST`, `PG_PORT`, `PG_USER`, `PG_PASSWORD` from secret
  - **Strategy**: RollingUpdate (maxSurge:1, maxUnavailable:0)

**Why**: Core application services implementing the voting workflow: vote collection → processing → results display.

### 5. Ingress (`ingress/`)

**AWS Load Balancer Controller Integration**

- **vote-ingress** (`ingress/vote-ingress.yaml`)
  - **IngressClass**: `alb`
  - **Scheme**: internet-facing
  - **Target Type**: ip (direct pod routing)
  - **Backend**: `vote` service on port 80
  - **Health Checks**: `/health` endpoint (15s interval, 5s timeout, 2/2 threshold)
  - **Listener**: HTTP port 80

- **result-ingress** (`ingress/result-ingress.yaml`)
  - **IngressClass**: `alb`
  - **Scheme**: internet-facing
  - **Target Type**: ip (direct pod routing)
  - **Backend**: `result` service on port 80
  - **Health Checks**: `/health` endpoint (15s interval, 5s timeout, 2/2 threshold)
  - **Listener**: HTTP port 80

**Why**: Expose vote and result services to the internet via AWS Application Load Balancer. ALB Controller automatically provisions and manages ALBs based on Ingress resources.

## Resource Dependencies

```
1. EBS CSI Driver (Terraform-managed EKS addon)
   └─> StorageClass created

2. StorageClass ready
   └─> Redis StatefulSets deployed
       └─> PVCs provisioned
           └─> EBS volumes attached

3. External Secrets Operator (Helm-installed)
   └─> IAM role created (Terraform)
       └─> ClusterSecretStore configured
           └─> ExternalSecret syncs
               └─> Kubernetes Secret created

4. AWS Load Balancer Controller (Helm-installed)
   └─> IAM role created (Terraform)
       └─> Watches Ingress resources

5. Application Stack (depends on above)
   ├─> Redis Primary/Replica ready
   ├─> RDS credentials synced
   ├─> vote Deployment → Service → Ingress → ALB
   ├─> result Deployment → Service → Ingress → ALB
   └─> worker Deployment (connects to Redis + RDS)
```

## Deployed Services

| Service | Type | Endpoint | Purpose |
|---------|------|----------|---------|
| `vote` | ClusterIP | `vote.default.svc.cluster.local:80` | Vote frontend service |
| `result` | ClusterIP | `result.default.svc.cluster.local:80` | Results dashboard service |
| `redis-primary` | ClusterIP | `redis-primary.default.svc.cluster.local:6379` | Redis write operations |
| `redis-replica` | ClusterIP | `redis-replica.default.svc.cluster.local:6379` | Redis read operations |
| `redis-headless` | Headless | `redis-primary-0.redis-headless.default.svc.cluster.local:6379` | StatefulSet stable DNS |

## Secrets Available

| Secret | Namespace | Fields | Source |
|--------|-----------|--------|--------|
| `rds-credentials` | default | username, password, host, port, dbname | AWS Secrets Manager |

## Verification Commands

```bash
# Check storage
kubectl get storageclass
kubectl get pvc

# Check Redis
kubectl get pods -l app=redis
kubectl get svc -l app=redis
kubectl exec -it redis-primary-0 -- redis-cli ping
kubectl exec -it redis-primary-0 -- redis-cli INFO replication

# Check secrets
kubectl get clustersecretstore
kubectl get externalsecret
kubectl get secret rds-credentials
kubectl get secret rds-credentials -o jsonpath='{.data.host}' | base64 -d

# Check External Secrets Operator
kubectl get pods -n external-secrets-system
kubectl get sa external-secrets -n external-secrets-system -o yaml | grep role-arn

# Check applications
kubectl get deployments
kubectl get pods -l app=vote
kubectl get pods -l app=worker
kubectl get pods -l app=result
kubectl get svc vote result
kubectl logs -l app=vote --tail=20
kubectl logs -l app=worker --tail=20
kubectl logs -l app=result --tail=20

# Check ingress and ALB
kubectl get ingress
kubectl describe ingress vote-ingress
kubectl describe ingress result-ingress
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Get ALB endpoints
kubectl get ingress vote-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
kubectl get ingress result-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Future Additions

This directory will expand to include:
- **Phase 5**: Monitoring stack (Prometheus, Grafana, custom dashboards)
- **Phase 6**: Advanced features (HPA, custom metrics, service mesh)

## Usage in Application Code

### Connecting to Redis (Primary for writes)
```yaml
env:
  - name: REDIS_HOST
    value: "redis-primary.default.svc.cluster.local"
  - name: REDIS_PORT
    value: "6379"
```

### Connecting to Redis (Replica for reads)
```yaml
env:
  - name: REDIS_REPLICA_HOST
    value: "redis-replica.default.svc.cluster.local"
  - name: REDIS_REPLICA_PORT
    value: "6379"
```

### Connecting to RDS PostgreSQL
```yaml
env:
  - name: DB_HOST
    valueFrom:
      secretKeyRef:
        name: rds-credentials
        key: host
  - name: DB_PORT
    valueFrom:
      secretKeyRef:
        name: rds-credentials
        key: port
  - name: DB_NAME
    valueFrom:
      secretKeyRef:
        name: rds-credentials
        key: dbname
  - name: DB_USER
    valueFrom:
      secretKeyRef:
        name: rds-credentials
        key: username
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: rds-credentials
        key: password
```

## Notes

- All persistent data survives pod restarts/deletions
- Redis replicas are read-only; writes must go to primary
- EBS volumes are encrypted at rest (AWS-managed keys)
- Secrets are automatically refreshed every hour from AWS Secrets Manager
- StatefulSets provide stable network identities and ordered deployment/scaling
