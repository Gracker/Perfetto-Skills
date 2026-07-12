-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/network_analysis.skill.yaml
-- Source SHA-256: 2608305b18a6513dfcc208dc9b7094457f4b581a131e6abecd7116b127802254
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

SELECT
  'trace_direct:packet_activity' AS evidence_class,
  'android_network_packets 可支持包收发、接口、协议、socket tag、远程端口、活跃周期和流量规模判断' AS supported_claims,
  '不能直接证明 DNS/TCP/TLS/TTFB/请求体/响应体/解码/服务端处理阶段耗时、HTTPDNS 缓存/TTL、ECH/CT/local-network permission/NetworkCallback 状态或请求级根因' AS unsupported_claims,
  '需要 OkHttp/Cronet/HttpEngine/自研网络库阶段埋点、request_id/trace_id、接入层日志、APM、NetworkCallback/dumpsys connectivity 或系统网络状态快照补证' AS required_complement
