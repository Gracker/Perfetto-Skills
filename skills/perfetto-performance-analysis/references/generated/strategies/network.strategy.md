GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/network.strategy.md
Source SHA-256: a493c2db8bbd3fa503b4fc5381c9dc6f50f796a81b8794b342a29e4de6eab6b2
Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

# Network Strategy

Portable methodology extracted from the SmartPerfetto strategy library.

`execute_sql(...)` examples mean to run the contained SQL through `perfetto_query.py`; they do not require a product tool.

## Portable execution commands

- List Skills: `python3 <skill-root>/scripts/perfetto_skill.py list`.
- Run a Skill: `python3 <skill-root>/scripts/perfetto_skill.py run TRACE --skill SKILL --output-dir DIR`.
- Run one query: `python3 <skill-root>/scripts/perfetto_query.py TRACE --query-id SKILL/STEP --output RESULT.json`.
- Compare side summaries: `python3 <skill-root>/scripts/perfetto_compare.py --side NAME=SUMMARY.json --baseline NAME`.
- Read and write evidence as ordinary local JSON files; no artifact, session, snapshot, or host-tool API exists.

## Portable strategy metadata

```yaml
scene: network
priority: 6
effort: medium
required_capabilities: []
optional_capabilities:
- network_packets
- power_rails
- battery_counters
keywords:
- 网络
- 流量
- 数据包
- network
- traffic
- packet
- wifi
- cellular
- 4g
- 5g
- tcp
- udp
- dns
- tls
- ttfb
- httpdns
- okhttp
- cronet
- httpengine
- http/3
- quic
- ech
- networkcallback
- networkcapabilities
- local network permission
compound_patterns:
- 网络.*(流量|耗电|唤醒|请求|包)
- network.*(traffic|power|wakeup|packet)
- (网络|network).*(慢|延迟|latency|slow|请求慢|request.*slow)
- (请求|request).*(慢|耗时|延迟|latency|slow)
- (OkHttp|Cronet|HttpEngine|HTTPDNS|NetworkCallback|NetworkCapabilities).*(DNS|TLS|TTFB|request|请求|cache|缓存|validated|metered|bandwidth|带宽)
- (DNS|TLS|TTFB|HTTPDNS|ECH|HTTP/3|HTTP3|QUIC).*(网络|请求|耗时|失败|latency|slow|failure)
- (local network permission|ACCESS_LOCAL_NETWORK|Certificate Transparency|Encrypted Client Hello).*(Android|targetSdk|网络|请求|失败|permission|policy)
final_report_contract:
  required_sections:
  - id: request_stage_evidence_boundary
    label: 请求阶段证据边界
    description: 当问题涉及 DNS/connect/TLS/TTFB/body/decode/HTTPDNS/OkHttp/Cronet/APM/接入层日志时，区分 packet trace、request telemetry、日志/APM、时间窗/request_id
      对齐和缺失证据。
    trigger_patterns:
    - (网络|network).*(慢|延迟|latency|slow|请求慢|request.*slow)|(请求|request).*(慢|耗时|延迟|latency|slow)
    - DNS|TTFB|HTTPDNS|OkHttp|Cronet|HttpEngine|EventListener|request[- ]stage|首包|首字节|secureConnect|responseHeadersStart
    - TLS|handshake|\bconnect(?:Start|End)?\b|request body|response body|body transfer|decode|server log|access[- ]layer|APM
    pattern_groups:
    - - 请求阶段证据边界
      - request[- ]stage evidence
      - DNS/TCP/TLS/TTFB
      - 阶段证据
    - - packet[- ]level
      - trace_direct:packet_activity
      - request[- ]level
      - request telemetry
      - OkHttp
      - Cronet
      - HttpEngine
      - EventListener
      - APM
      - 接入层
      - 日志
    - - DNS
      - connect
      - TLS
      - TTFB
      - first byte
      - request body
      - response body
      - decode
      - HTTPDNS
      - cache
      - retry
      - 首包
      - 首字节
    - - request_id
      - trace_id
      - 时间窗
      - window
      - align
      - 对齐
      - missing
      - 缺失
      - 置信
      - confidence
      - 不能
      - 不可
      - not prove
  - id: network_stack_policy_boundary
    label: 网络栈/版本策略边界
    description: 当问题涉及 Cronet/HttpEngine/HTTP3/QUIC/ECH/CT/NetworkCallback/local-network permission/validated/metered/satellite/constrained
      network 时，区分网络栈、API/targetSdk/Extension、设备/服务端支持、配置/权限和 trace packet 证据。
    trigger_patterns:
    - Cronet|HttpEngine|HTTP/3|HTTP3|QUIC|0[- ]RTT|ECH|Encrypted Client Hello|Certificate Transparency|\bCT\b
    - NetworkCallback|NetworkCapabilities|validated internet|metered|estimated bandwidth|bandwidth estimate|local network
      permission|ACCESS_LOCAL_NETWORK|satellite|constrained network
    pattern_groups:
    - - 网络栈/版本策略边界
      - stack policy boundary
      - 版本策略
      - network stack
    - - Cronet
      - HttpEngine
      - HTTP/3
      - HTTP3
      - QUIC
      - NetworkCallback
      - NetworkCapabilities
      - ECH
      - Encrypted Client Hello
      - Certificate Transparency
      - local network permission
      - ACCESS_LOCAL_NETWORK
    - - Android\s*1[67]
      - API\s*3[4-7]
      - targetSdk
      - Extension
      - SDK
      - 版本
      - 配置
      - server support
      - permission
      - policy
      - 能力
    - - trace_direct
      - packet
      - config
      - log
      - dumpsys
      - APM
      - missing
      - 缺失
      - 置信
      - confidence
      - 不能
      - 不可
phase_hints:
- id: network_packets
  keywords:
  - network
  - traffic
  - packet
  - 网络
  - 流量
  - 数据包
  - tcp
  - udp
  constraints: 优先调用 network_analysis。若 android_network_packets 不存在或为空，必须标注 trace 未启用 network_packets，不能解释为没有网络活动。
  critical_tools:
  - network_analysis
  critical: true
- id: network_power
  keywords:
  - battery
  - power
  - wakeup
  - 耗电
  - 唤醒
  - 掉电
  constraints: 网络耗电问题需要把 network_analysis 与 battery_drain_attribution / power_consumption_overview 组合，区分网络事件链和 rail 级功耗归因。
  critical_tools:
  - network_analysis
  - battery_drain_attribution
  - power_consumption_overview
  critical: false
- id: request_stage_boundary
  keywords:
  - DNS
  - TLS
  - TTFB
  - HTTPDNS
  - OkHttp
  - Cronet
  - HttpEngine
  - EventListener
  - APM
  - request-stage
  - 首包
  - 首字节
  constraints: request-stage 归因必须先说明 packet-level trace 只能证明包/接口/协议/活跃窗口；只有存在 OkHttp/Cronet/HttpEngine 事件、request_id、app trace
    slice、接入层日志或 APM 且与当前时间窗对齐时，才能拆 DNS/connect/TLS/TTFB/body/decode/cache/retry。缺失时输出采集建议。
  critical_tools:
  - network_analysis
  critical: false
- id: network_state_policy_boundary
  keywords:
  - ECH
  - Encrypted Client Hello
  - Certificate Transparency
  - HTTP/3
  - QUIC
  - NetworkCallback
  - NetworkCapabilities
  - validated
  - metered
  - local network permission
  - ACCESS_LOCAL_NETWORK
  - satellite
  - constrained network
  constraints: 网络栈/政策问题必须把当前 trace packet 证据、client stack/config、Android/API/targetSdk/Extension、NetworkCallback/NetworkCapabilities、dumpsys/connectivity、服务端支持和外部错误日志分开；版本或配置未知时不得提升为确定根因。
  critical_tools:
  - network_analysis
  critical: false
plan_template:
  mandatory_aspects:
  - id: network_data
    match_keywords:
    - network_analysis
    - network
    - 网络
    - 流量
    - packet
    suggestion: 网络场景必须先调用 network_analysis 或明确说明 network_packets 数据缺失
    required_expected_calls:
    - skill_id: network_analysis
  - id: network_power_context
    match_keywords:
    - battery_drain_attribution
    - power_consumption_overview
    - 耗电
    - 唤醒
    - power
    suggestion: 网络耗电/唤醒问题需要补充功耗或唤醒上下文
    required_expected_call_alternatives:
    - skill_id: battery_drain_attribution
    - skill_id: power_consumption_overview
```

#### network Core Strategy

**Route card**: 网络 / 流量 / 数据包 / network / traffic / packet / wifi / cellular / 4g / 5g

**Capabilities**: required=[none], optional=[network_packets, power_rails, battery_counters]

**Final report contract summary**
- 请求阶段证据边界
- 网络栈/版本策略边界


<!-- strategy-detail id="full" title="network full strategy detail" keywords="network,网络,流量,数据包,network,traffic,packet,wifi,cellular,4g,5g,tcp,udp,网络活动分析,detail,full" default="true" -->
#### 网络活动分析

网络场景先判断 trace 是否真的采集了 `android.network_packets`。如果没有该数据源，只能给采集建议，不能把空结果解释为"没有网络问题"。

`network_analysis` 的 packet-level 证据只能说明包收发、接口、协议、socket tag、远程端口、活跃周期和流量规模。它不能直接证明 DNS/TCP/TLS/TTFB/服务端处理这些 request-stage 根因；只有同时存在 OkHttp/Cronet/自研网络库阶段埋点、业务 trace/request id、接入层日志或系统网络状态快照时，才允许按请求阶段归因。

**Phase 1 — 网络流量/协议/接口总览：**


重点看接口分布、方向、协议、socket tag、活跃周期。如果用户关心具体时间段，必须传入 `start_ts` / `end_ts`。

输出时把证据类型写清楚：
1. `trace_direct`: packet/activity/traffic 证据，可用于流量、频繁活跃、功耗相关性。
2. `missing_evidence`: 没有 request-stage telemetry 时，DNS/连接/TLS/TTFB 只能列为待补证方向。
3. `external_context`: 若用户提供 APM/接入层指标，只能作为上下文，必须和当前 trace 窗口对齐后再提升置信度。

**Phase 1.5 — 请求阶段证据边界（按需）：**

当用户问“网络慢”“请求慢”“DNS/TLS/TTFB 慢”“HTTPDNS 缓存/TTL”“OkHttp/Cronet/HttpEngine 阶段耗时”时，先把证据分层：

1. `packet_trace`: `network_analysis` 只能证明包收发、接口、协议、远端端口、socket tag、活跃窗口和流量规模。
2. `request_telemetry`: OkHttp `EventListener`、Cronet/HttpEngine 事件、app trace slice、request_id/trace_id 才能拆 DNS/connect/TLS/request body/TTFB/response body/decode/cache/retry。
3. `log_or_snapshot`: 接入层日志、客户端错误码、`NetworkCallback` 状态、`dumpsys connectivity` 可提供语义和网络状态，但必须和当前 trace 时间窗对齐。
4. `external_aggregate`: APM、服务端指标、线上弱网统计只能作为背景，不能替代当前 trace 证据。

缺少 request-level telemetry 时，结论必须写成 `missing_evidence`：当前只能证明网络活动/流量候选，不能直接把根因定为 DNS、TLS、首包、服务端处理或解码慢。需要机制背景时调用：


**Phase 1.6 — 网络栈/版本策略边界（按需）：**

当问题涉及 ECH、Certificate Transparency、HTTP/3/QUIC、0-RTT、Cronet、HttpEngine、`NetworkCallback`、validated/metered/bandwidth、satellite/constrained network 或 local network permission 时，必须拆开：

1. `client_stack`: OkHttp、Cronet、HttpEngine、自研 socket 栈，不同栈的 DNS/TLS/QUIC/HTTP3 能力和事件命名不同。
2. `platform_policy`: Android/API/targetSdk/Extension、权限、Network Security Config、证书/CT/ECH 配置、服务端支持。
3. `network_state`: `NetworkCapabilities` 的 validated internet、metered、transport、bandwidth estimate 是网络状态，不是请求阶段耗时本身。
4. `trace_scope`: packet trace 只能看到流量和活跃窗口；没有 app/config/log 证据时，不能把 ECH、CT、local-network permission 或 HTTP3/QUIC 配置写成确定根因。

截至 2026-05-30 核对的官方边界：HttpEngine 是 Android 版本化网络 API，通常由 Cronet 提供实现；Android 16 local-network protection 是 opt-in，Android 17 targetSdk 37+ 才强制本地网络权限；Android 17 ECH 需要目标 SDK、网络库集成和服务端支持共同满足。目标设备版本、targetSdk、网络栈和服务端能力未知时，一律标为版本/配置缺失。

**Phase 2 — 网络耗电/唤醒链路：**


如果 power_rails 可用，再补：


输出时明确区分：
1. 网络包/活跃周期证据
2. wakelock / suspend-wakeup / job 事件链
3. rail 级能耗归因是否可用
<!-- /strategy-detail -->
