GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/knowledge-perfetto-sql.template.md
Source SHA-256: 8bddcad6eba5f915ad9dbcb2396a168a3ab912701fbf7bb884b27256148d05cf

# Knowledge Perfetto Sql Template

Portable methodology extracted from the SmartPerfetto strategy library.

`execute_sql(...)` examples mean to run the contained SQL through `perfetto_query.py`; they do not require a product tool.

## Portable execution commands

- List Skills: `python3 <skill-root>/scripts/perfetto_skill.py list`.
- Run a Skill: `python3 <skill-root>/scripts/perfetto_skill.py run TRACE --skill SKILL --output-dir DIR`.
- Run one query: `python3 <skill-root>/scripts/perfetto_query.py TRACE --query-id SKILL/STEP --output RESULT.json`.
- Compare side summaries: `python3 <skill-root>/scripts/perfetto_compare.py --side NAME=SUMMARY.json --baseline NAME`.
- Read and write evidence as ordinary local JSON files; no artifact, session, snapshot, or host-tool API exists.

<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
<!-- Copyright (C) 2024-2026 Gracker (Chris) | the portable runtime -->

## SQL

ts/dur: ns. = exact; GLOB wildcard; regexp(pattern,input,'i') opt-in partial.
No TP tables: mm_event/page_fault/lmks/frames/thread_track_name/cpu_frequency_track/freq.
SQLite scalar `MAX(a,b)/MIN(a,b)`, no GREATEST/LEAST. `MAX(x)` aggregates.
|slice|id,ts,dur,track_id,name,parent_id|
|thread_track|id,utid|
|thread|utid,tid,upid,name,is_main_thread,is_idle|
|process|upid,pid,name|
|sched|ts,dur,cpu,utid,priority,end_state|
|thread_state|ts,dur,utid,state,blocked_function,waker_utid|
|android_binder_txns=android.binder|client_ts,client_dur,server_ts,server_dur,client_upid,server_upid,is_sync,aidl_name|
|actual_frame_timeline_slice|ts,dur,upid,jank_type,jank_tag,surface_frame_token,display_frame_token|
|counter|ts,track_id,value|
`INCLUDE PERFETTO MODULE <module>;` first:
android_monitor_contention=android.monitor_contention (no s); android_startups=android.startup.startups.
`slice s JOIN thread_track tt ON s.track_id=tt.id JOIN thread t ON tt.utid=t.utid JOIN process p USING(upid)`.
TID/PID!=UTID/UPID.
`counter c JOIN counter_track t ON c.track_id=t.id`; CPU=cpu_counter_track.
Binder: no ts/dur; ORDER BY client_ts
LAG/LEAD OVER: SELECT/ORDER BY; no AVG/SUM(window); CTE then WHERE/AVG/ROUND: `WITH w AS(SELECT ts-LAG(ts) OVER(PARTITION BY track_id ORDER BY ts) gap FROM counter) SELECT AVG(gap),COUNT(gap) FROM w`.
USING shared; slice:no upid/utid; qualify; unique aliases.
