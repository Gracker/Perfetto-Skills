-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/dmabuf_analysis.skill.yaml
-- Source SHA-256: 82544957bb27c764d3304e2acc9a3306fa7fab10dc9b095bcfe0cae0798b53f6
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH alloc_stats AS (
  SELECT
    COUNT(*) AS total_allocs,
    ROUND(SUM(CASE WHEN buf_size > 0 THEN buf_size ELSE 0 END) / 1024.0 / 1024.0, 2) AS total_alloc_mb,
    ROUND(SUM(buf_size) / 1024.0 / 1024.0, 2) AS net_alloc_mb
  FROM android_dmabuf_allocs
  WHERE (CASE WHEN '${package}' != ''
              THEN process_name GLOB '*${package}*'
              ELSE 1 END)
    AND (${start_ts} IS NULL OR ts > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
lifecycle_stats AS (
  WITH allocs AS (
    SELECT inode, ts AS alloc_ts, buf_size, process_name
    FROM android_dmabuf_allocs
    WHERE buf_size > 0
      AND (CASE WHEN '${package}' != ''
                THEN process_name GLOB '*${package}*'
                ELSE 1 END)
      AND (${start_ts} IS NULL OR ts > ${start_ts})
      AND (${end_ts} IS NULL OR ts < ${end_ts})
  ),
  frees AS (
    SELECT inode, ts AS free_ts
    FROM android_dmabuf_allocs
    WHERE buf_size < 0
      AND (${start_ts} IS NULL OR ts > ${start_ts})
      AND (${end_ts} IS NULL OR ts < ${end_ts})
  ),
  lifecycles AS (
    SELECT
      a.process_name,
      MIN(f.free_ts) AS free_ts
    FROM allocs a
    LEFT JOIN frees f ON a.inode = f.inode AND f.free_ts > a.alloc_ts
    GROUP BY a.inode, a.alloc_ts
  )
  SELECT
    COUNT(*) AS buffer_count,
    COUNT(free_ts) AS freed_count,
    COUNT(*) - COUNT(free_ts) AS not_freed_count
  FROM lifecycles
),
frequency_stats AS (
  SELECT
    COUNT(*) AS total_events,
    CASE WHEN (MAX(ts) - MIN(ts)) > 0
      THEN ROUND(COUNT(*) * 1.0e9 / (MAX(ts) - MIN(ts)), 2)
      ELSE 0
    END AS events_per_second
  FROM android_dmabuf_allocs
  WHERE buf_size > 0
    AND (CASE WHEN '${package}' != ''
              THEN process_name GLOB '*${package}*'
              ELSE 1 END)
    AND (${start_ts} IS NULL OR ts > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
)
SELECT * FROM (
  -- DMABUF_LEAK: 大量未释放 Buffer
  SELECT
    'DMABUF_LEAK' AS category,
    'critical' AS severity,
    'DMA-BUF 内存泄漏：大量 Buffer 未被释放' AS description,
    '未释放 ' || CAST(l.not_freed_count AS TEXT) || '/' || CAST(l.buffer_count AS TEXT)
      || ' 个 Buffer（'
      || CAST(ROUND(100.0 * l.not_freed_count / MAX(l.buffer_count, 1), 1) AS TEXT) || '%）'
      || '，净分配 ' || CAST(a.net_alloc_mb AS TEXT) || 'MB' AS evidence
  FROM lifecycle_stats l, alloc_stats a
  WHERE l.not_freed_count > 20 AND l.not_freed_count > l.buffer_count * 0.3

  UNION ALL

  -- DMABUF_PRESSURE: 高净分配量
  SELECT
    'DMABUF_PRESSURE' AS category,
    'critical' AS severity,
    'DMA-BUF 内存压力：净分配量过高' AS description,
    '净分配 ' || CAST(a.net_alloc_mb AS TEXT) || 'MB'
      || '，总分配 ' || CAST(a.total_alloc_mb AS TEXT) || 'MB' AS evidence
  FROM alloc_stats a
  WHERE a.net_alloc_mb > 200

  UNION ALL

  -- DMABUF_CHURN: 高频分配释放
  SELECT
    'DMABUF_CHURN' AS category,
    'warning' AS severity,
    'DMA-BUF 频繁分配释放（churn）' AS description,
    '分配频率 ' || CAST(f.events_per_second AS TEXT) || ' 次/秒'
      || '，总分配 ' || CAST(f.total_events AS TEXT) || ' 次' AS evidence
  FROM frequency_stats f
  WHERE f.events_per_second > 10

  UNION ALL

  -- DMABUF_LARGE_ALLOC: 单次大分配
  SELECT
    'DMABUF_LARGE_ALLOC' AS category,
    'warning' AS severity,
    '存在大型 DMA-BUF 分配' AS description,
    '最大单次分配 '
      || CAST(ROUND(MAX(buf_size) / 1024.0 / 1024.0, 2) AS TEXT) || 'MB' AS evidence
  FROM android_dmabuf_allocs
  WHERE buf_size > 0
    AND buf_size / 1024.0 / 1024.0 > 50
    AND (CASE WHEN '${package}' != ''
              THEN process_name GLOB '*${package}*'
              ELSE 1 END)
    AND (${start_ts} IS NULL OR ts > ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})

  UNION ALL

  -- DMABUF_NORMAL: 正常
  SELECT
    'DMABUF_NORMAL' AS category,
    'info' AS severity,
    'DMA-BUF 使用正常' AS description,
    '总分配 ' || CAST(a.total_allocs AS TEXT) || ' 次'
      || '，净分配 ' || CAST(a.net_alloc_mb AS TEXT) || 'MB'
      || '，未释放 ' || CAST(l.not_freed_count AS TEXT) || ' 个' AS evidence
  FROM alloc_stats a, lifecycle_stats l
  WHERE a.net_alloc_mb <= 200
    AND l.not_freed_count <= 20
)
ORDER BY CASE severity
  WHEN 'critical' THEN 1
  WHEN 'warning' THEN 2
  WHEN 'info' THEN 3
END
