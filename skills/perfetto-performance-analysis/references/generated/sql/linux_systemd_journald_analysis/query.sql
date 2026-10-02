-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/linux_systemd_journald_analysis.skill.yaml
-- Source SHA-256: 73a21e2a0fac64fb3e80030be4225b2c9e9051438c21557277bedf2ac1988aa2

WITH input AS (
  SELECT
    MIN(MAX(COALESCE(${max_prio|4}, 4), 0), 7) AS max_prio,
    MIN(MAX(COALESCE(${max_rows|80}, 80), 1), 500) AS max_rows
),
entries AS (
  SELECT
    ts,
    prio,
    CASE prio
      WHEN 0 THEN 'EMERG'
      WHEN 1 THEN 'ALERT'
      WHEN 2 THEN 'CRIT'
      WHEN 3 THEN 'ERROR'
      WHEN 4 THEN 'WARN'
      WHEN 5 THEN 'NOTICE'
      WHEN 6 THEN 'INFO'
      WHEN 7 THEN 'DEBUG'
      ELSE 'UNKNOWN'
    END AS prio_label,
    tag,
    comm,
    systemd_unit,
    hostname,
    transport,
    msg,
    CASE
      WHEN prio <= 3 THEN 'error_or_higher'
      WHEN prio = 4 THEN 'warning'
      WHEN LOWER(COALESCE(msg, '')) GLOB '*panic*'
        OR LOWER(COALESCE(msg, '')) GLOB '*crash*'
        OR LOWER(COALESCE(msg, '')) GLOB '*oom*'
        OR LOWER(COALESCE(msg, '')) GLOB '*timeout*'
        OR LOWER(COALESCE(msg, '')) GLOB '*failed*'
        THEN 'keyword_signal'
      ELSE 'other'
    END AS signal_type
  FROM linux_systemd_journald_logs
  WHERE (${start_ts} IS NULL OR ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
    AND ('${unit|}' = '' OR instr(LOWER(COALESCE(systemd_unit, '')), LOWER('${unit|}')) > 0)
    AND ('${tag|}' = '' OR instr(LOWER(COALESCE(tag, '')), LOWER('${tag|}')) > 0)
),
selected AS (
  SELECT
    printf('%d', ts) AS ts_str,
    prio_label,
    signal_type,
    COALESCE(tag, '') AS tag,
    COALESCE(comm, '') AS comm,
    COALESCE(systemd_unit, '') AS systemd_unit,
    COALESCE(hostname, '') AS hostname,
    COALESCE(transport, '') AS transport,
    SUBSTR(COALESCE(msg, ''), 1, 240) AS msg_preview,
    ts AS sort_ts
  FROM entries, input
  WHERE prio <= input.max_prio
    OR signal_type <> 'other'
  ORDER BY ts
  LIMIT (SELECT max_rows FROM input)
)
SELECT
  ts_str,
  prio_label,
  signal_type,
  tag,
  comm,
  systemd_unit,
  hostname,
  transport,
  msg_preview
FROM selected
UNION ALL
SELECT
  '0' AS ts_str,
  'NONE' AS prio_label,
  'no_journald_rows' AS signal_type,
  '' AS tag,
  '' AS comm,
  '' AS systemd_unit,
  '' AS hostname,
  '' AS transport,
  'No linux_systemd_journald_logs rows matched the current filters.' AS msg_preview
WHERE NOT EXISTS (SELECT 1 FROM entries)
