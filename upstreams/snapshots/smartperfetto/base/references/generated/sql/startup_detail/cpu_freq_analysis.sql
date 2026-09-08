-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/startup_detail.skill.yaml
-- Source SHA-256: 658b23722c587abee0359b3f5dab8309cb85bc5a9136213edf874debba758e39
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

WITH main_thread AS (
  SELECT t.utid, t.tid, p.pid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE ('${package}' = '' OR p.name = '${package}' OR p.name GLOB '${package}:*')
    AND t.tid = p.pid
),
running_samples AS (
  SELECT
    ss.cpu,
    ss.ts,
    ss.dur,
    COALESCE(ct.core_type, 'unknown') as core_type
  FROM sched_slice ss
  JOIN main_thread mt ON ss.utid = mt.utid
  LEFT JOIN _cpu_topology ct ON ss.cpu = ct.cpu_id
  WHERE ss.ts < ${end_ts}
    AND ss.ts + ss.dur > ${start_ts}
),
freq_samples AS (
  SELECT
    cf.cpu,
    cf.freq as freq_khz,
    rs.core_type,
    MIN(cf.ts + cf.dur, ${end_ts}) - MAX(cf.ts, rs.ts) as overlap_dur
  FROM cpu_frequency_counters cf
  JOIN running_samples rs ON cf.cpu = rs.cpu
  WHERE cf.ts < ${end_ts}
    AND cf.ts + cf.dur > rs.ts
    AND cf.ts < rs.ts + rs.dur
)
SELECT
  core_type,
  ROUND(SUM(freq_khz * overlap_dur) / NULLIF(SUM(overlap_dur), 0) / 1000, 0) as avg_freq_mhz,
  ROUND(MAX(freq_khz) / 1000, 0) as max_freq_mhz,
  ROUND(MIN(freq_khz) / 1000, 0) as min_freq_mhz,
  'topology_view' as classify_method
FROM freq_samples
WHERE overlap_dur > 0
GROUP BY core_type
ORDER BY core_type DESC
