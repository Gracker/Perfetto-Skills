-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/anr_main_thread_blocking.skill.yaml
-- Source SHA-256: 125f6c0f585e4fb4e02d376ddf8c103f5229e42fbdff3be9b176133960f18834

SELECT CAST(w_start AS TEXT) AS start_ts, CAST(w_end AS TEXT) AS end_ts
FROM (
  SELECT
    COALESCE(${start_ts}, ${anr_ts} - 5000000000, (SELECT MIN(ts) FROM slice)) AS w_start,
    COALESCE(${end_ts}, ${anr_ts} + 1000000000, (SELECT MAX(ts + dur) FROM slice)) AS w_end
)
