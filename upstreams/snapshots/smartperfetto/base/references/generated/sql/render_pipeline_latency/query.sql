-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/render_pipeline_latency.skill.yaml
-- Source SHA-256: 485299ac47ece0112e0d06665583b421d13314d59be5ff19a7286223dab81d4b
-- Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

WITH timing AS (
  SELECT
    ${end_ts} - ${start_ts} as total_dur,
    COALESCE(${main_end_ts}, ${end_ts}) - COALESCE(${main_start_ts}, ${start_ts}) as main_dur,
    COALESCE(${render_end_ts}, ${end_ts}) - COALESCE(${render_start_ts}, ${start_ts}) as render_dur,
    COALESCE(${main_start_ts}, ${start_ts}) - ${start_ts} as pre_main_dur,
    CASE
      WHEN ${render_start_ts} IS NOT NULL AND ${main_end_ts} IS NOT NULL
      THEN ${render_start_ts} - ${main_end_ts}
      ELSE 0
    END as handoff_dur
  WHERE ${end_ts} > ${start_ts}
)
SELECT '1. 帧总耗时' as stage,
  ROUND(total_dur / 1e6, 2) as dur_ms,
  100.0 as pct
FROM timing
UNION ALL
SELECT '2. 主线程 (UI 构建)' as stage,
  ROUND(main_dur / 1e6, 2) as dur_ms,
  ROUND(100.0 * main_dur / NULLIF(total_dur, 0), 1) as pct
FROM timing
UNION ALL
SELECT '3. RenderThread (GPU 指令)' as stage,
  ROUND(render_dur / 1e6, 2) as dur_ms,
  ROUND(100.0 * render_dur / NULLIF(total_dur, 0), 1) as pct
FROM timing
UNION ALL
SELECT '4. 主线程→RT 交接' as stage,
  ROUND(handoff_dur / 1e6, 2) as dur_ms,
  ROUND(100.0 * handoff_dur / NULLIF(total_dur, 0), 1) as pct
FROM timing
WHERE handoff_dur > 0
