# poll-broker Service Diagrams

## Internal Architecture

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'primaryColor':'#e5e7eb','primaryTextColor':'#111827','primaryBorderColor':'#9ca3af','lineColor':'#111827','secondaryColor':'#d1d5db','tertiaryColor':'#f3f4f6','edgeLabelBackground':'#ffffff','mainBkg':'#f5f5f4','nodeBorder':'#9ca3af','background':'#f5f5f4','clusterBkg':'transparent'},'themeCSS':'.node rect, .node circle, .node ellipse, .node polygon, .node path { filter: none !important; box-shadow: none !important; } .cluster rect { filter: none !important; box-shadow: none !important; } svg { background-color: #f5f5f4 !important; } .cluster-label { background-color: #ffffff !important; padding: 6px 12px !important; border-radius: 4px !important; font-size: 16px !important; font-weight: 700 !important; box-shadow: 0 1px 3px rgba(0,0,0,0.12) !important; border: 1px solid #d1d5db !important; } .edgePath, .edgePath path, .flowchart-link { z-index: 1 !important; }'}}%%

graph TB
    subgraph PollBroker["poll-broker process"]
        Main[main.go\nstartup + orchestration]
        MetricsSrv[Metrics server\n:9090/metrics]

        subgraph Goroutines["Goroutines (context-cancellable)"]
            Poller[Poller\ntick every 10s]
            Processor[Processor\ntight loop]
            Broadcaster[Broadcaster\ntick every 1s]
        end

        subgraph Packages["Internal packages"]
            Logger[logger\nlogrus + JSON\nservice=poll-broker]
            DB[database\nPostgreSQL pool]
            Cache[cache\nioredis client]
        end
    end

    Redis[(Redis)]
    PG[(PostgreSQL)]
    Prometheus[(Prometheus\nscrape :9090)]

    Main -->|starts| Poller
    Main -->|starts| Processor
    Main -->|starts| Broadcaster
    Main -->|serves| MetricsSrv

    Poller --> DB
    Poller --> Cache
    Processor --> DB
    Processor --> Cache
    Broadcaster --> DB
    Broadcaster --> Cache

    DB <-->|queries| PG
    Cache <-->|pub/sub + queue| Redis
    Prometheus -->|scrape| MetricsSrv

    style PollBroker fill:#d1d5db,stroke:#4b5563,stroke-width:2px,stroke-dasharray: 5 5
    style Goroutines fill:#f3f4f6,stroke:#6b7280,stroke-width:1px,stroke-dasharray: 5 5
    style Packages fill:#f3f4f6,stroke:#6b7280,stroke-width:1px,stroke-dasharray: 5 5

    style Main fill:#3B82F6,stroke:#333,color:#fff
    style MetricsSrv fill:#F59E0B,stroke:#333,color:#fff
    style Poller fill:#3B82F6,stroke:#333,color:#fff
    style Processor fill:#3B82F6,stroke:#333,color:#fff
    style Broadcaster fill:#3B82F6,stroke:#333,color:#fff
    style Logger fill:#6B7280,stroke:#333,color:#fff
    style DB fill:#8B5CF6,stroke:#333,color:#fff
    style Cache fill:#8B5CF6,stroke:#333,color:#fff
    style Redis fill:#8B5CF6,stroke:#333,color:#fff
    style PG fill:#8B5CF6,stroke:#333,color:#fff
    style Prometheus fill:#F59E0B,stroke:#333,color:#fff
```

## Poller Goroutine Flow

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'primaryColor':'#e5e7eb','primaryTextColor':'#111827','primaryBorderColor':'#9ca3af','lineColor':'#111827','secondaryColor':'#d1d5db','tertiaryColor':'#f3f4f6','edgeLabelBackground':'#ffffff','mainBkg':'#f5f5f4','nodeBorder':'#9ca3af','background':'#f5f5f4','clusterBkg':'transparent'},'themeCSS':'.node rect, .node circle, .node ellipse, .node polygon, .node path { filter: none !important; box-shadow: none !important; } .cluster rect { filter: none !important; box-shadow: none !important; } svg { background-color: #f5f5f4 !important; } .cluster-label { background-color: #ffffff !important; padding: 6px 12px !important; border-radius: 4px !important; font-size: 16px !important; font-weight: 700 !important; box-shadow: 0 1px 3px rgba(0,0,0,0.12) !important; border: 1px solid #d1d5db !important; } .edgePath, .edgePath path, .flowchart-link { z-index: 1 !important; }'}}%%

flowchart TD
    Start([poller started\nevent: poller_started])
    Tick[Wait 10s ticker]

    subgraph Activate["Activate pending polls"]
        QA[DB: GetPollsToActivate\nactivate_at <= NOW\nstatus = pending]
        UA[DB: UpdatePollStatus\n→ active]
        PA[Redis: PUBLISH poll:lifecycle\nevent: poll_activated]
    end

    subgraph Close["Close expired polls"]
        QC[DB: GetPollsToClose\nend_time <= NOW\nstatus = active]
        UC[DB: UpdatePollStatus\n→ closed]
        PC[Redis: PUBLISH poll:lifecycle\nevent: poll_closed]
    end

    Cancel{ctx.Done?}
    End([poller cancelled\nevent: poller_cancelled])

    Start --> Tick
    Tick --> Cancel
    Cancel -->|no| QA
    Cancel -->|yes| End
    QA --> UA --> PA
    PA --> QC
    QC --> UC --> PC
    PC --> Tick

    style Start fill:#10B981,stroke:#333,color:#fff
    style End fill:#EF4444,stroke:#333,color:#fff
    style Tick fill:#3B82F6,stroke:#333,color:#fff
    style Cancel fill:#F97316,stroke:#333,color:#fff
    style Activate fill:#f3f4f6,stroke:#6b7280,stroke-dasharray: 5 5
    style Close fill:#f3f4f6,stroke:#6b7280,stroke-dasharray: 5 5
    style QA fill:#8B5CF6,stroke:#333,color:#fff
    style UA fill:#8B5CF6,stroke:#333,color:#fff
    style PA fill:#8B5CF6,stroke:#333,color:#fff
    style QC fill:#8B5CF6,stroke:#333,color:#fff
    style UC fill:#8B5CF6,stroke:#333,color:#fff
    style PC fill:#8B5CF6,stroke:#333,color:#fff
```

## Processor Goroutine Flow

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'primaryColor':'#e5e7eb','primaryTextColor':'#111827','primaryBorderColor':'#9ca3af','lineColor':'#111827','secondaryColor':'#d1d5db','tertiaryColor':'#f3f4f6','edgeLabelBackground':'#ffffff','mainBkg':'#f5f5f4','nodeBorder':'#9ca3af','background':'#f5f5f4','clusterBkg':'transparent'},'themeCSS':'.node rect, .node circle, .node ellipse, .node polygon, .node path { filter: none !important; box-shadow: none !important; } .cluster rect { filter: none !important; box-shadow: none !important; } svg { background-color: #f5f5f4 !important; } .cluster-label { background-color: #ffffff !important; padding: 6px 12px !important; border-radius: 4px !important; font-size: 16px !important; font-weight: 700 !important; box-shadow: 0 1px 3px rgba(0,0,0,0.12) !important; border: 1px solid #d1d5db !important; } .edgePath, .edgePath path, .flowchart-link { z-index: 1 !important; }'}}%%

flowchart TD
    Start([processor started\nevent: processor_started])
    BLP[Redis: BLPOP votes:queue\nblocking 5s timeout]
    Nil{got item?}
    Validate{valid vote?}
    Insert[DB: INSERT INTO votes\npoll_id, option, user_ip]
    LogOk[log: vote_recorded]
    LogFail[log: error]
    Cancel{ctx.Done?}
    End([processor stopped\nevent: processor_stopped])

    Start --> BLP
    BLP --> Nil
    Nil -->|no item / timeout| Cancel
    Nil -->|item| Validate
    Validate -->|invalid| LogFail
    Validate -->|valid| Insert
    Insert --> LogOk
    LogOk --> Cancel
    LogFail --> Cancel
    Cancel -->|no| BLP
    Cancel -->|yes| End

    style Start fill:#10B981,stroke:#333,color:#fff
    style End fill:#EF4444,stroke:#333,color:#fff
    style BLP fill:#8B5CF6,stroke:#333,color:#fff
    style Nil fill:#F97316,stroke:#333,color:#fff
    style Validate fill:#F97316,stroke:#333,color:#fff
    style Insert fill:#8B5CF6,stroke:#333,color:#fff
    style LogOk fill:#10B981,stroke:#333,color:#fff
    style LogFail fill:#EF4444,stroke:#333,color:#fff
    style Cancel fill:#F97316,stroke:#333,color:#fff
```

## Broadcaster Goroutine Flow

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'primaryColor':'#e5e7eb','primaryTextColor':'#111827','primaryBorderColor':'#9ca3af','lineColor':'#111827','secondaryColor':'#d1d5db','tertiaryColor':'#f3f4f6','edgeLabelBackground':'#ffffff','mainBkg':'#f5f5f4','nodeBorder':'#9ca3af','background':'#f5f5f4','clusterBkg':'transparent'},'themeCSS':'.node rect, .node circle, .node ellipse, .node polygon, .node path { filter: none !important; box-shadow: none !important; } .cluster rect { filter: none !important; box-shadow: none !important; } svg { background-color: #f5f5f4 !important; } .cluster-label { background-color: #ffffff !important; padding: 6px 12px !important; border-radius: 4px !important; font-size: 16px !important; font-weight: 700 !important; box-shadow: 0 1px 3px rgba(0,0,0,0.12) !important; border: 1px solid #d1d5db !important; } .edgePath, .edgePath path, .flowchart-link { z-index: 1 !important; }'}}%%

flowchart TD
    Start([broadcaster started\nevent: broadcaster_started])
    Tick[Wait 1s ticker]
    Cancel{ctx.Done?}
    GetPolls[DB: GetActivePolls]
    ErrPolls{error?}
    LogPollsErr[log: broadcast_active_polls_error]
    ForEach[for each active poll]
    GetResults[DB: GetPollResults poll_id]
    Publish[Redis: PUBLISH poll:results\n{ poll_id, optionA, optionB, total }]
    LogPub[log: broadcast_poll_success]
    LogFail[log: broadcast_poll_failed]
    End([broadcaster stopped\nevent: broadcaster_stopped])

    Start --> Tick
    Tick --> Cancel
    Cancel -->|yes| End
    Cancel -->|no| GetPolls
    GetPolls --> ErrPolls
    ErrPolls -->|error| LogPollsErr
    ErrPolls -->|ok| ForEach
    LogPollsErr --> Tick
    ForEach --> GetResults
    GetResults --> Publish
    Publish --> LogPub
    LogPub --> ForEach
    Publish -->|error| LogFail
    LogFail --> ForEach
    ForEach -->|done| Tick

    style Start fill:#10B981,stroke:#333,color:#fff
    style End fill:#EF4444,stroke:#333,color:#fff
    style Tick fill:#3B82F6,stroke:#333,color:#fff
    style Cancel fill:#F97316,stroke:#333,color:#fff
    style GetPolls fill:#8B5CF6,stroke:#333,color:#fff
    style ErrPolls fill:#F97316,stroke:#333,color:#fff
    style LogPollsErr fill:#EF4444,stroke:#333,color:#fff
    style ForEach fill:#3B82F6,stroke:#333,color:#fff
    style GetResults fill:#8B5CF6,stroke:#333,color:#fff
    style Publish fill:#8B5CF6,stroke:#333,color:#fff
    style LogPub fill:#10B981,stroke:#333,color:#fff
    style LogFail fill:#EF4444,stroke:#333,color:#fff
```
