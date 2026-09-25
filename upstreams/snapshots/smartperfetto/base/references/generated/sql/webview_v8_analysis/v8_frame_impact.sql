-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/webview_v8_analysis.skill.yaml
-- Source SHA-256: 21b4aad17749f3d884e964c264f1cafceef566b01f105da76394c1ae7f0b20ca
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

SELECT
  printf('%d', gc.ts) as gc_ts,
  gc.name as gc_name,
  ROUND(gc.dur / 1e6, 2) as gc_dur_ms,
  ROUND(af.dur / 1e6, 2) as frame_dur_ms,
  af.jank_type,
  ROUND(
    (MIN(gc.ts + gc.dur, af.ts + af.dur) - MAX(gc.ts, af.ts)) / 1e6, 2
  ) as overlap_ms
FROM slice gc
JOIN thread_track tt ON gc.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
JOIN actual_frame_timeline_slice af ON (
  af.upid = p.upid
  AND gc.ts < af.ts + af.dur
  AND gc.ts + gc.dur > af.ts
)
WHERE (('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*') OR '${package}' = '')
  AND (${start_ts} IS NULL OR gc.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR gc.ts + gc.dur <= ${end_ts})
  AND (gc.name GLOB '*v8.gc*' OR gc.name GLOB '*V8.GC*'
       OR gc.name GLOB '*MajorGC*' OR gc.name GLOB '*MinorGC*'
       OR gc.name GLOB '*V8.GCScavenger*' OR gc.name GLOB '*V8.GCCompactor*')
ORDER BY gc.dur DESC
LIMIT 30
