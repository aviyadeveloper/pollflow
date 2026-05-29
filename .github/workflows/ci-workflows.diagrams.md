# CI/CD Workflow Diagrams

## test.yml: Unit & Integration Tests (PR → main)

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'primaryColor':'#e5e7eb','primaryTextColor':'#111827','primaryBorderColor':'#9ca3af','lineColor':'#111827','secondaryColor':'#d1d5db','tertiaryColor':'#f3f4f6','edgeLabelBackground':'#ffffff','mainBkg':'#f5f5f4','nodeBorder':'#9ca3af','background':'#f5f5f4','clusterBkg':'transparent'},'themeCSS':'.node rect, .node circle, .node ellipse, .node polygon, .node path { filter: none !important; box-shadow: none !important; } .cluster rect { filter: none !important; box-shadow: none !important; } svg { background-color: #f5f5f4 !important; } .cluster-label { background-color: #ffffff !important; padding: 6px 12px !important; border-radius: 4px !important; font-size: 16px !important; font-weight: 700 !important; box-shadow: 0 1px 3px rgba(0,0,0,0.12) !important; border: 1px solid #d1d5db !important; } .edgePath, .edgePath path, .flowchart-link { z-index: 1 !important; }'}}%%

flowchart TD
    Trigger([PR opened/updated\ntargets: main])

    subgraph Parallel["Run in parallel"]
        PG[test-poll-generator\nubuntu-latest\npython 3.12\npytest services/poll-generator]
        PB[test-poll-broker\nubuntu-latest\ngo 1.23\ngo test ./...]
        FE[test-frontend\nubuntu-latest\nnode 22\nnpm ci + npm test]
        Build[build-poll-broker\nubuntu-latest\ngo 1.23\ngo build ./...]
    end

    Trigger --> PG
    Trigger --> PB
    Trigger --> FE
    Trigger --> Build

    style Trigger fill:#3B82F6,stroke:#333,color:#fff
    style Parallel fill:#f3f4f6,stroke:#6b7280,stroke-dasharray: 5 5
    style PG fill:#10B981,stroke:#333,color:#fff
    style PB fill:#10B981,stroke:#333,color:#fff
    style FE fill:#10B981,stroke:#333,color:#fff
    style Build fill:#10B981,stroke:#333,color:#fff
```

## build-and-deploy.yml: Build & Deploy (push → main)

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'primaryColor':'#e5e7eb','primaryTextColor':'#111827','primaryBorderColor':'#9ca3af','lineColor':'#111827','secondaryColor':'#d1d5db','tertiaryColor':'#f3f4f6','edgeLabelBackground':'#ffffff','mainBkg':'#f5f5f4','nodeBorder':'#9ca3af','background':'#f5f5f4','clusterBkg':'transparent'},'themeCSS':'.node rect, .node circle, .node ellipse, .node polygon, .node path { filter: none !important; box-shadow: none !important; } .cluster rect { filter: none !important; box-shadow: none !important; } svg { background-color: #f5f5f4 !important; } .cluster-label { background-color: #ffffff !important; padding: 6px 12px !important; border-radius: 4px !important; font-size: 16px !important; font-weight: 700 !important; box-shadow: 0 1px 3px rgba(0,0,0,0.12) !important; border: 1px solid #d1d5db !important; } .edgePath, .edgePath path, .flowchart-link { z-index: 1 !important; }'}}%%

flowchart TD
    Trigger([push to main\nservices/** or k8s/apps/**])

    subgraph Validate["Job: validate (ubuntu-latest, go 1.23)"]
        GFmt[go fmt ./...]
        GVet[go vet ./...]
        GBuild[go build ./...]
        GFmt --> GVet --> GBuild
    end

    subgraph BuildMatrix["Job: build (matrix: frontend, poll-broker)"]
        OIDC[OIDC → assume\npollflow-github-actions role]
        ECRLogin[aws ecr get-login-password\ndocker login]
        DockerBuild["docker build\n--build-arg COMMIT_SHA\n-t {ECR_URL}/{service}:{sha}"]
        DockerPush[docker push]
        OIDC --> ECRLogin --> DockerBuild --> DockerPush
    end

    subgraph Deploy["Job: deploy (ubuntu-latest)"]
        OIDC2[OIDC → assume role]
        Kubeconfig[aws eks update-kubeconfig]
        KubectlApply[kubectl apply -f k8s/apps/\nkubectl apply -f k8s/redis/\nkubectl apply -f k8s/ingress/]
        OIDC2 --> Kubeconfig --> KubectlApply
    end

    Trigger --> Validate
    Validate -->|needs: validate| BuildMatrix
    BuildMatrix -->|needs: build| Deploy

    style Trigger fill:#3B82F6,stroke:#333,color:#fff
    style Validate fill:#f3f4f6,stroke:#6b7280,stroke-dasharray: 5 5
    style BuildMatrix fill:#f3f4f6,stroke:#6b7280,stroke-dasharray: 5 5
    style Deploy fill:#f3f4f6,stroke:#6b7280,stroke-dasharray: 5 5

    style GFmt fill:#10B981,stroke:#333,color:#fff
    style GVet fill:#10B981,stroke:#333,color:#fff
    style GBuild fill:#10B981,stroke:#333,color:#fff
    style OIDC fill:#EF4444,stroke:#333,color:#fff
    style OIDC2 fill:#EF4444,stroke:#333,color:#fff
    style ECRLogin fill:#F97316,stroke:#333,color:#fff
    style DockerBuild fill:#6B7280,stroke:#333,color:#fff
    style DockerPush fill:#F97316,stroke:#333,color:#fff
    style Kubeconfig fill:#3B82F6,stroke:#333,color:#fff
    style KubectlApply fill:#3B82F6,stroke:#333,color:#fff
```

## terraform.yml: Infrastructure Validation (PR with infra/** changes)

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'primaryColor':'#e5e7eb','primaryTextColor':'#111827','primaryBorderColor':'#9ca3af','lineColor':'#111827','secondaryColor':'#d1d5db','tertiaryColor':'#f3f4f6','edgeLabelBackground':'#ffffff','mainBkg':'#f5f5f4','nodeBorder':'#9ca3af','background':'#f5f5f4','clusterBkg':'transparent'},'themeCSS':'.node rect, .node circle, .node ellipse, .node polygon, .node path { filter: none !important; box-shadow: none !important; } .cluster rect { filter: none !important; box-shadow: none !important; } svg { background-color: #f5f5f4 !important; } .cluster-label { background-color: #ffffff !important; padding: 6px 12px !important; border-radius: 4px !important; font-size: 16px !important; font-weight: 700 !important; box-shadow: 0 1px 3px rgba(0,0,0,0.12) !important; border: 1px solid #d1d5db !important; } .edgePath, .edgePath path, .flowchart-link { z-index: 1 !important; }'}}%%

flowchart TD
    Trigger([PR with infra/**\nchanges])

    subgraph FmtCheck["Job: fmt-check (parallel per dir)"]
        FmtB[terraform fmt -check\ntf-bootstrap/]
        FmtM[terraform fmt -check\ntf-main/]
    end

    subgraph Validate["Job: validate (parallel per dir)"]
        ValB[terraform init -backend=false\nterraform validate\ntf-bootstrap/]
        ValM[terraform init -backend=false\nterraform validate\ntf-main/]
    end

    Gate[terraform-gate\nalways-pass\ngates mergeability]

    Trigger --> FmtB
    Trigger --> FmtM
    FmtB -->|needs: fmt-check| ValB
    FmtM -->|needs: fmt-check| ValM
    ValB --> Gate
    ValM --> Gate

    style Trigger fill:#3B82F6,stroke:#333,color:#fff
    style FmtCheck fill:#f3f4f6,stroke:#6b7280,stroke-dasharray: 5 5
    style Validate fill:#f3f4f6,stroke:#6b7280,stroke-dasharray: 5 5

    style FmtB fill:#F97316,stroke:#333,color:#fff
    style FmtM fill:#F97316,stroke:#333,color:#fff
    style ValB fill:#F97316,stroke:#333,color:#fff
    style ValM fill:#F97316,stroke:#333,color:#fff
    style Gate fill:#10B981,stroke:#333,color:#fff
```
