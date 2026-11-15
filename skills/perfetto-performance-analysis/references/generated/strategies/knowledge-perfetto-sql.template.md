GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/knowledge-perfetto-sql.template.md
Source SHA-256: 66644d899ebf051542950f5999a9d160575c3d441a7185970ebc9c0433de0ff5

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

## Perfetto SQL

| Relation | Columns |
| --- | --- |
| slice | id,ts,dur,track_id,name,parent_id |
| thread_track | id,utid |
| thread | utid,tid,upid,name,is_main_thread,is_idle |
| process | upid,pid,name |
| sched | ts,dur,cpu,utid,priority,end_state |
| thread_state | ts,dur,utid,state,blocked_function,waker_utid |
| android_binder_txns | client_ts,client_dur,server_ts,server_dur,client_upid,server_upid,is_sync,aidl_name |
| actual_frame_timeline_slice | ts,dur,upid,jank_type,jank_tag,surface_frame_token,display_frame_token |
| counter | ts,track_id,value |

Slices: `slice s JOIN thread_track tt ON s.track_id=tt.id JOIN thread t ON tt.utid=t.utid JOIN process p ON t.upid=p.upid`.
TID/PID != UTID/UPID; thread tracks: thread slices only.
android_binder_txns: no ts/dur; ORDER BY client_ts.

LAG/LEAD need OVER; CTE then WHERE/aggregate: `WITH w AS(SELECT c.ts-LAG(c.ts) OVER(PARTITION BY c.track_id ORDER BY c.ts) gap FROM counter c) SELECT AVG(w.gap) FROM w`.
USING(x): both sides need x. slice lacks upid/utid; use thread_track.
Joins: unique aliases; qualify SELECT/ON/WHERE/ORDER BY columns.
