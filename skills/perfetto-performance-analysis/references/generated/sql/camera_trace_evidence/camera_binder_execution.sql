-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/camera_trace_evidence.skill.yaml
-- Source SHA-256: 51f50653a5676ed9b3c272fc9c6fc7f51b670240aaf0b404b6b7fea9bdb6a994

WITH input AS (
 SELECT MIN(COALESCE(${start_ts},trace_start()),COALESCE(${end_ts},trace_end())) AS start_ts,
   MAX(COALESCE(${start_ts},trace_start()),COALESCE(${end_ts},trace_end())) AS end_ts,
   MIN(MAX(COALESCE(${max_rows|20},20),1),100) AS max_rows
), states AS (
 SELECT binder_txn_id,binder_reply_id,
   SUM(CASE WHEN thread_state_type='binder_reply' THEN 1 ELSE 0 END) AS server_state_rows,
   SUM(CASE WHEN thread_state_type='binder_reply' AND thread_state='Running' THEN thread_state_dur ELSE 0 END) AS server_running_ns,
   SUM(CASE WHEN thread_state_type='binder_reply' THEN thread_state_dur ELSE 0 END) AS server_state_ns
 FROM android_sync_binder_thread_state_by_txn GROUP BY binder_txn_id,binder_reply_id
), txns AS (
 SELECT b.*, CASE WHEN s.server_state_rows>0 THEN s.server_running_ns END AS server_running_ns,
   CASE WHEN s.server_state_rows>0 THEN s.server_state_ns END AS server_state_ns
 FROM android_binder_txns b LEFT JOIN states s USING (binder_txn_id,binder_reply_id),input i
 WHERE b.is_sync=1 AND b.client_dur>=0 AND b.server_dur>=0
   AND b.client_ts>=i.start_ts AND b.client_ts+b.client_dur<=i.end_ts
   AND (lower(COALESCE(b.client_process,'')) GLOB '*camera*' OR lower(COALESCE(b.server_process,'')) GLOB '*camera*'
     OR lower(COALESCE(b.client_process,'')) GLOB '*camx*' OR lower(COALESCE(b.server_process,'')) GLOB '*camx*'
     OR lower(COALESCE(b.client_process,'')) GLOB '*mtkcam*' OR lower(COALESCE(b.server_process,'')) GLOB '*mtkcam*')
)
SELECT client_upid,server_upid,client_process,server_process,COUNT(*) AS transactions,
 AVG(client_dur) AS avg_client_wall_ns,AVG(server_dur) AS avg_server_wall_ns,
 COUNT(server_running_ns) AS server_state_observed_txns,
 AVG(server_running_ns) AS avg_server_running_ns,AVG(server_state_ns) AS avg_server_state_observed_ns,
 'not_measured' AS headroom_status,
 'Complete transactions starting and ending in the window. Wall includes waits; Running covers only the bound server thread. Neither measures sensor budget, pipeline depth, in-flight capacity or headroom. No state rows means unknown Running, not zero.' AS limitation,
 COUNT(*) OVER () AS total_groups
FROM txns GROUP BY client_upid,server_upid ORDER BY transactions DESC LIMIT (SELECT max_rows FROM input)
