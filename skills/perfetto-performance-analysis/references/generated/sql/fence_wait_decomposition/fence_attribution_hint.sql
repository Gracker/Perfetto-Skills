-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/fence_wait_decomposition.skill.yaml
-- Source SHA-256: 182d5e6b03a0ccfbd53f5da992628513e87e9afe773539e0fc312d54148568af
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

WITH
sf_proc AS (
  SELECT upid FROM process WHERE name = 'surfaceflinger' LIMIT 1
),
acquire_p95_ns AS (
  SELECT (SELECT dur_ns FROM (
    SELECT s.dur as dur_ns, ROW_NUMBER() OVER (ORDER BY s.dur) as rn,
           COUNT(*) OVER () as total
    FROM slice s
    JOIN thread_track tt ON s.track_id = tt.id
    JOIN thread t ON tt.utid = t.utid
    WHERE t.upid IN (SELECT upid FROM sf_proc)
      AND (s.name GLOB '*acquireBuffer*' OR s.name GLOB '*latchBuffer*')
      AND s.ts >= ${start_ts} AND s.ts < ${end_ts}
      AND s.dur > 0
  ) WHERE rn = CAST(total * 0.95 AS INTEGER) LIMIT 1) as v
),
present_p95_ns AS (
  SELECT (SELECT dur_ns FROM (
    SELECT s.dur as dur_ns, ROW_NUMBER() OVER (ORDER BY s.dur) as rn,
           COUNT(*) OVER () as total
    FROM slice s
    JOIN thread_track tt ON s.track_id = tt.id
    JOIN thread t ON tt.utid = t.utid
    WHERE t.upid IN (SELECT upid FROM sf_proc)
      AND s.name GLOB '*presentDisplay*'
      AND s.ts >= ${start_ts} AND s.ts < ${end_ts}
      AND s.dur > 0
  ) WHERE rn = CAST(total * 0.95 AS INTEGER) LIMIT 1) as v
),
release_p95_ns AS (
  SELECT (SELECT dur_ns FROM (
    SELECT s.dur as dur_ns, ROW_NUMBER() OVER (ORDER BY s.dur) as rn,
           COUNT(*) OVER () as total
    FROM slice s
    WHERE s.name GLOB '*dequeueBuffer*'
      AND s.ts >= ${start_ts} AND s.ts < ${end_ts}
      AND s.dur > 0
  ) WHERE rn = CAST(total * 0.95 AS INTEGER) LIMIT 1) as v
)
SELECT
  CASE
    WHEN COALESCE((SELECT v FROM release_p95_ns), 0) > 5e6
      THEN 'release_fence (dequeueBuffer 阻塞)'
    WHEN COALESCE((SELECT v FROM present_p95_ns), 0) > 5e6
      THEN 'present_fence (系统收尾段慢)'
    WHEN COALESCE((SELECT v FROM acquire_p95_ns), 0) > 5e6
      THEN 'acquire_fence (Producer GPU 写入慢)'
    ELSE 'no_dominant_fence_issue'
  END as dominant_fence_issue,
  CASE
    WHEN COALESCE((SELECT v FROM release_p95_ns), 0) > 5e6
      THEN '上一帧 buffer 卡 ACQUIRED 状态：HWC 还在显示/SF 没释放/triple buffer 不足'
    WHEN COALESCE((SELECT v FROM present_p95_ns), 0) > 5e6
      THEN 'Panel 模式切换/刷新率切换/扫描输出本身延迟（DSI/DP）；5ms 为固定启发式，需结合实际 VSync 周期复核'
    WHEN COALESCE((SELECT v FROM acquire_p95_ns), 0) > 5e6
      THEN 'Producer GPU 写入慢；多 layer 场景看哪条 layer fence 晚'
    ELSE '三种 fence 都在正常范围；问题可能在锚点 ②③④⑤（生产段）或 ⑨⑩（HWC 决策段）'
  END as hint
