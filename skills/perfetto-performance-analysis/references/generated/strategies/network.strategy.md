GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/network.strategy.md
Source SHA-256: a493c2db8bbd3fa503b4fc5381c9dc6f50f796a81b8794b342a29e4de6eab6b2
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

# Network Strategy

Portable methodology extracted from the SmartPerfetto strategy library.

#### network Core Strategy

**Route card**: 网络 / 流量 / 数据包 / network / traffic / packet / wifi / cellular / 4g / 5g

**Capabilities**: required=[none], optional=[network_packets, power_rails, battery_counters]





**Phase reminders**
- network_packets: 优先调用 network_analysis。若 android_network_packets 不存在或为空，必须标注 trace 未启用 network_packets，不能解释为没有网络活动。 工具: network_analysis
- network_power: 网络耗电问题需要把 network_analysis 与 battery_drain_attribution / power_consumption_overview 组合，区分网络事件链和 rail 级功耗归因。 工具: network_analysis, battery_drain_attribution, power_consumption_overview
- request_stage_boundary: request-stage 归因必须先说明 packet-level trace 只能证明包/接口/协议/活跃窗口；只有存在 OkHttp/Cronet/HttpEngine 事件、request_id、app trace slice、接入层日志或 APM 且与当前时间窗对齐时，才能拆 DNS/connect/TLS/TTFB/body/decode/cache/retry。缺失时输出采集建议。 工具: network_analysis, lookup_knowledge
- network_state_policy_boundary: 网络栈/政策问题必须把当前 trace packet 证据、client stack/config、Android/API/targetSdk/Extension、NetworkCallback/NetworkCapabilities、dumpsys/connectivity、服务端支持和外部错误日志分开；版本或配置未知时不得提升为确定根因。 工具: network_analysis, lookup_knowledge

**Final report contract summary**
- 请求阶段证据边界
- 网络栈/版本策略边界


**Detail ref**
- `network:full`: 网络活动分析 的完整 phase recipe、SQL、fetch_artifact 表、决策树和边界说明。


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

```
lookup_knowledge("network-evidence")
```

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
