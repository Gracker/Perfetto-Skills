-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/game_main_loop_jank.skill.yaml
-- Source SHA-256: 174f4c55bf6e3f9deed54eb0413221f154230454cb2b49437a87e6831cd3a251
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

WITH
input AS (
  SELECT
    COALESCE(NULLIF('${package|}', ''), NULLIF('${process_name|}', ''), '') AS target_process,
    COALESCE(${target_frame_ms}, 16.67) AS target_frame_ms,
    COALESCE(${start_ts}, 0) AS start_ts,
    COALESCE(${end_ts}, (SELECT COALESCE(MAX(ts + dur), 0) FROM slice)) AS end_ts
),
engine_processes AS (
  SELECT DISTINCT p.upid
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  JOIN process p ON t.upid = p.upid
  CROSS JOIN input i
  WHERE (i.target_process = '' OR p.name GLOB i.target_process || '*')
    AND s.ts >= i.start_ts
    AND s.ts < i.end_ts
    AND (
      t.name GLOB '*Unity*' OR t.name GLOB '*GameThread*' OR t.name GLOB '*RHIThread*' OR
      s.name GLOB '*Unity*' OR s.name GLOB '*PlayerLoop*' OR s.name GLOB '*Camera.Render*' OR s.name GLOB '*Gfx.WaitForPresent*' OR
      s.name GLOB '*FrameGameThread*' OR s.name GLOB '*Unreal*' OR
      s.name GLOB '*Director::mainLoop*' OR s.name GLOB '*cocos2d*' OR s.name GLOB '*Cocos*' OR
      s.name GLOB '*Main::iteration*' OR s.name GLOB '*physics_process*' OR s.name GLOB '*idle_process*'
    )
)
SELECT
  printf('%d', s.ts) AS ts,
  printf('%d', s.dur) AS dur_ns,
  ROUND(s.dur / 1e6, 2) AS dur_ms,
  CASE
    WHEN t.name GLOB '*Unity*' OR s.name GLOB '*Unity*' OR s.name GLOB '*PlayerLoop*' THEN 'Unity'
    WHEN t.name GLOB '*GameThread*' OR t.name GLOB '*RHIThread*' OR s.name GLOB '*FrameGameThread*' OR s.name GLOB '*Unreal*' THEN 'Unreal'
    WHEN s.name GLOB '*Director::mainLoop*' OR s.name GLOB '*cocos2d*' OR s.name GLOB '*Cocos*' THEN 'Cocos'
    WHEN s.name GLOB '*Main::iteration*' OR s.name GLOB '*physics_process*' OR s.name GLOB '*idle_process*' THEN 'Godot'
    ELSE 'GenericGame'
  END AS engine_family,
  CASE
    WHEN s.name GLOB '*Gfx.WaitForPresent*' OR s.name GLOB '*WaitForPresent*' THEN 'present_wait'
    WHEN s.name GLOB '*Camera.Render*' OR s.name GLOB '*UnityGfx*' OR s.name GLOB '*RenderingThread*' OR t.name GLOB '*RHIThread*' THEN 'render'
    WHEN s.name GLOB '*Tick*' OR s.name GLOB '*Update*' OR s.name GLOB '*PlayerLoop*' OR s.name GLOB '*FrameGameThread*' THEN 'tick_update'
    WHEN s.name GLOB '*Director::mainLoop*' OR s.name GLOB '*Main::iteration*' THEN 'main_loop'
    ELSE 'engine_work'
  END AS phase,
  s.name AS slice_name,
  t.name AS thread_name,
  p.name AS process_name
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
CROSS JOIN input i
WHERE (i.target_process = '' OR p.name GLOB i.target_process || '*')
  AND p.upid IN (SELECT upid FROM engine_processes)
  AND s.ts >= i.start_ts
  AND s.ts < i.end_ts
  AND s.dur / 1e6 > i.target_frame_ms * 1.5
  AND (
    t.name GLOB '*Unity*' OR t.name GLOB '*GameThread*' OR t.name GLOB '*RHIThread*' OR
    t.name GLOB '*Unity*' OR t.name GLOB '*GameThread*' OR t.name GLOB '*RHIThread*' OR
    t.name GLOB '*GLThread*' OR
    s.name GLOB '*PlayerLoop*' OR s.name GLOB '*Camera.Render*' OR s.name GLOB '*Gfx.WaitForPresent*' OR
    s.name GLOB '*FrameGameThread*' OR s.name GLOB '*Unreal*' OR
    s.name GLOB '*Director::mainLoop*' OR s.name GLOB '*cocos2d*' OR s.name GLOB '*Cocos*' OR
    s.name GLOB '*Main::iteration*' OR s.name GLOB '*physics_process*' OR s.name GLOB '*idle_process*'
  )
ORDER BY s.dur DESC
LIMIT 100
