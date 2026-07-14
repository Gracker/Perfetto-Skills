-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gc_analysis.skill.yaml
-- Source SHA-256: 9953952ad063229e1a5f04d58a41962bce74d74d1c303ca177cb7055c0afb366
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

WITH gc_stats AS (
  SELECT
    COUNT(*) AS total_gc_count,
    ROUND(SUM(gc_dur) / 1e6, 2) AS total_gc_dur_ms,
    ROUND(MAX(gc_dur) / 1e6, 2) AS max_gc_dur_ms,
    ROUND(AVG(gc_dur) / 1e6, 2) AS avg_gc_dur_ms,
    ROUND(SUM(reclaimed_mb), 2) AS total_reclaimed_mb,
    ROUND(AVG(reclaimed_mb), 2) AS avg_reclaimed_mb,
    ROUND(MAX(max_heap_mb), 2) AS peak_heap_mb,
    ROUND(MIN(min_heap_mb), 2) AS trough_heap_mb,
    SUM(CASE WHEN gc_type = 'alloc' THEN 1 ELSE 0 END) AS alloc_gc_count,
    SUM(CASE WHEN gc_type = 'explicit' THEN 1 ELSE 0 END) AS explicit_gc_count,
    SUM(CASE WHEN gc_type = 'full' THEN 1 ELSE 0 END) AS full_gc_count,
    ROUND(
      COUNT(*) * 1e9 / NULLIF(MAX(gc_ts + gc_dur) - MIN(gc_ts), 0),
      2
    ) AS gc_per_second
  FROM android_garbage_collection_events
  WHERE CASE WHEN '${package}' != ''
             THEN process_name GLOB '*${package}*'
             ELSE 1 END
    AND (${start_ts} IS NULL OR gc_ts + gc_dur > ${start_ts})
    AND (${end_ts} IS NULL OR gc_ts < ${end_ts})
),
frame_impact AS (
  SELECT
    COUNT(*) AS jank_during_gc
  FROM android_garbage_collection_events gc
  JOIN actual_frame_timeline_slice f
    ON f.ts < gc.gc_ts + gc.gc_dur
    AND f.ts + f.dur > gc.gc_ts
  WHERE f.jank_type != 'None'
    AND CASE WHEN '${package}' != ''
             THEN gc.process_name GLOB '*${package}*'
             ELSE 1 END
    AND (${start_ts} IS NULL OR gc.gc_ts + gc.gc_dur > ${start_ts})
    AND (${end_ts} IS NULL OR gc.gc_ts < ${end_ts})
),
heap_trend AS (
  SELECT
    CASE
      WHEN (SELECT COUNT(*) FROM android_garbage_collection_events
            WHERE CASE WHEN '${package}' != ''
                       THEN process_name GLOB '*${package}*'
                       ELSE 1 END
              AND (${start_ts} IS NULL OR gc_ts + gc_dur > ${start_ts})
              AND (${end_ts} IS NULL OR gc_ts < ${end_ts})
           ) >= 4
        AND (
          SELECT AVG(max_heap_mb)
          FROM (
            SELECT max_heap_mb, ROW_NUMBER() OVER (ORDER BY gc_ts DESC) AS rn
            FROM android_garbage_collection_events
            WHERE CASE WHEN '${package}' != ''
                       THEN process_name GLOB '*${package}*'
                       ELSE 1 END
              AND (${start_ts} IS NULL OR gc_ts + gc_dur > ${start_ts})
              AND (${end_ts} IS NULL OR gc_ts < ${end_ts})
          )
          WHERE rn <= (
            SELECT COUNT(*) / 4 FROM android_garbage_collection_events
            WHERE CASE WHEN '${package}' != ''
                       THEN process_name GLOB '*${package}*'
                       ELSE 1 END
              AND (${start_ts} IS NULL OR gc_ts + gc_dur > ${start_ts})
              AND (${end_ts} IS NULL OR gc_ts < ${end_ts})
          )
        ) >
        (
          SELECT AVG(max_heap_mb) * 1.2
          FROM (
            SELECT max_heap_mb, ROW_NUMBER() OVER (ORDER BY gc_ts ASC) AS rn
            FROM android_garbage_collection_events
            WHERE CASE WHEN '${package}' != ''
                       THEN process_name GLOB '*${package}*'
                       ELSE 1 END
              AND (${start_ts} IS NULL OR gc_ts + gc_dur > ${start_ts})
              AND (${end_ts} IS NULL OR gc_ts < ${end_ts})
          )
          WHERE rn <= (
            SELECT COUNT(*) / 4 FROM android_garbage_collection_events
            WHERE CASE WHEN '${package}' != ''
                       THEN process_name GLOB '*${package}*'
                       ELSE 1 END
              AND (${start_ts} IS NULL OR gc_ts + gc_dur > ${start_ts})
              AND (${end_ts} IS NULL OR gc_ts < ${end_ts})
          )
        )
      THEN 1 ELSE 0
    END AS heap_growing
)
SELECT * FROM (
  -- GC_PRESSURE: 高频 GC + 高分配速率
  SELECT
    'GC_PRESSURE' AS category,
    'critical' AS severity,
    'GC 频率过高 (' || s.total_gc_count || ' 次, ' || COALESCE(s.gc_per_second, 0) || '/s)，内存分配压力大' AS description,
    '总 GC ' || s.total_gc_count || ' 次, alloc 触发 ' || s.alloc_gc_count || ' 次, 总耗时 ' || s.total_gc_dur_ms || 'ms' AS evidence
  FROM gc_stats s
  WHERE s.total_gc_count > 50 AND (s.alloc_gc_count > 20 OR COALESCE(s.gc_per_second, 0) > 3)

  UNION ALL

  -- GC_FRAME_IMPACT: GC 导致掉帧
  SELECT
    'GC_FRAME_IMPACT' AS category,
    'critical' AS severity,
    'GC 期间有 ' || fi.jank_during_gc || ' 帧发生 Jank，GC 导致掉帧' AS description,
    'Jank 帧数 ' || fi.jank_during_gc || ', 总 GC 耗时 ' || s.total_gc_dur_ms || 'ms' AS evidence
  FROM gc_stats s, frame_impact fi
  WHERE fi.jank_during_gc > 5

  UNION ALL

  -- GC_LONG_PAUSE: 单次 GC 耗时过长
  SELECT
    'GC_LONG_PAUSE' AS category,
    'warning' AS severity,
    '最长单次 GC 暂停 ' || s.max_gc_dur_ms || 'ms，可能导致明显卡顿' AS description,
    '最大 GC 耗时 ' || s.max_gc_dur_ms || 'ms, 平均 ' || s.avg_gc_dur_ms || 'ms' AS evidence
  FROM gc_stats s
  WHERE s.max_gc_dur_ms > 50

  UNION ALL

  -- GC_LEAK: 堆内存持续增长
  SELECT
    'GC_LEAK' AS category,
    'warning' AS severity,
    '堆内存呈增长趋势 (峰值 ' || s.peak_heap_mb || 'MB)，可能存在内存泄漏' AS description,
    '峰值堆 ' || s.peak_heap_mb || 'MB, 谷值堆 ' || s.trough_heap_mb || 'MB, full GC ' || s.full_gc_count || ' 次' AS evidence
  FROM gc_stats s, heap_trend ht
  WHERE ht.heap_growing = 1

  UNION ALL

  -- GC_EXPLICIT: 过多显式 GC 调用
  SELECT
    'GC_EXPLICIT' AS category,
    'warning' AS severity,
    '检测到 ' || s.explicit_gc_count || ' 次显式 GC 调用 (System.gc())' AS description,
    '显式 GC ' || s.explicit_gc_count || ' 次, 总 GC ' || s.total_gc_count || ' 次' AS evidence
  FROM gc_stats s
  WHERE s.explicit_gc_count > 3

  UNION ALL

  -- GC_NORMAL: 正常
  SELECT
    'GC_NORMAL' AS category,
    'info' AS severity,
    'GC 行为正常 (共 ' || s.total_gc_count || ' 次, 平均 ' || s.avg_gc_dur_ms || 'ms)' AS description,
    '总 GC ' || s.total_gc_count || ' 次, 总耗时 ' || s.total_gc_dur_ms || 'ms, 回收 ' || s.total_reclaimed_mb || 'MB' AS evidence
  FROM gc_stats s
  WHERE s.total_gc_count <= 50
    AND s.max_gc_dur_ms <= 50
    AND (SELECT jank_during_gc FROM frame_impact) <= 5
    AND (SELECT heap_growing FROM heap_trend) = 0
)
ORDER BY CASE severity
  WHEN 'critical' THEN 1
  WHEN 'warning' THEN 2
  WHEN 'info' THEN 3
END
