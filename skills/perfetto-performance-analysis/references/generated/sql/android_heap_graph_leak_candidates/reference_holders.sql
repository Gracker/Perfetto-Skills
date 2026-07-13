-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/android_heap_graph_leak_candidates.skill.yaml
-- Source SHA-256: 7b56ba3235b7962f0119ea09d450af39eba9c021da1cb714c40db3d5c2064ce7
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

WITH
input AS (
  SELECT
    COALESCE(NULLIF('${process_name|}', ''), NULLIF('${package|}', ''), '') AS target_process,
    NULLIF('${class_name_glob|}', '') AS class_name_glob,
    COALESCE(NULLIF('${lifecycle_slice_prefix|SI$}', ''), '') AS lifecycle_prefix,
    MIN(MAX(COALESCE(${max_candidates|50}, 50), 1), 200) AS max_candidates,
    MIN(MAX(COALESCE(${max_reference_edges|100}, 100), 1), 500) AS max_reference_edges
),
heap_objects AS (
  SELECT
    o.id AS object_id,
    o.upid,
    o.graph_sample_ts,
    COALESCE(p.name, printf('upid:%d', o.upid)) AS process_name,
    COALESCE(c.deobfuscated_name, c.name) AS class_name,
    o.self_size,
    COALESCE(o.native_size, 0) AS native_size
  FROM heap_graph_object o
  JOIN heap_graph_class c ON o.type_id = c.id
  LEFT JOIN process p ON p.upid = o.upid
  CROSS JOIN input
  WHERE o.reachable = 1
    AND (input.target_process = '' OR p.name GLOB input.target_process || '*')
    AND (${graph_sample_ts} IS NULL OR o.graph_sample_ts = ${graph_sample_ts})
    AND COALESCE(c.deobfuscated_name, c.name) NOT IN (
      'android.app.Activity',
      'android.app.Fragment',
      'androidx.fragment.app.Fragment',
      'androidx.activity.ComponentActivity',
      'androidx.appcompat.app.AppCompatActivity'
    )
    AND (
      COALESCE(c.deobfuscated_name, c.name) GLOB '*Activity'
      OR COALESCE(c.deobfuscated_name, c.name) GLOB '*Activity$*'
      OR COALESCE(c.deobfuscated_name, c.name) GLOB '*Activity_*'
      OR COALESCE(c.deobfuscated_name, c.name) GLOB '*Fragment'
      OR COALESCE(c.deobfuscated_name, c.name) GLOB '*Fragment$*'
      OR COALESCE(c.deobfuscated_name, c.name) GLOB '*Fragment_*'
      OR (input.class_name_glob IS NOT NULL AND COALESCE(c.deobfuscated_name, c.name) GLOB input.class_name_glob)
    )
),
class_candidates AS (
  SELECT
    upid,
    graph_sample_ts,
    process_name,
    class_name,
    COUNT(*) AS reachable_obj_count,
    SUM(self_size) AS self_size_bytes
  FROM heap_objects
  GROUP BY upid, graph_sample_ts, process_name, class_name
),
candidate_states AS (
  SELECT
    c.*,
    (
      SELECT
        CASE
          WHEN s.name GLOB '*onDestroyView*' THEN 'destroyed'
          WHEN s.name GLOB '*onDestroy*' THEN 'destroyed'
          WHEN s.name GLOB '*onPause*' THEN 'inactive'
          WHEN s.name GLOB '*onStop*' THEN 'inactive'
          WHEN s.name GLOB '*onResume*' THEN 'active'
          WHEN s.name GLOB '*onStart*' THEN 'active'
          WHEN s.name GLOB '*onCreate*' THEN 'active'
          ELSE 'unknown'
        END
      FROM slice s
      JOIN thread_track tt ON s.track_id = tt.id
      JOIN thread t ON tt.utid = t.utid
      JOIN process p ON t.upid = p.upid
      CROSS JOIN input
      WHERE p.upid = c.upid
        AND s.dur >= 0
        AND s.ts + s.dur <= c.graph_sample_ts
        AND (
          (input.lifecycle_prefix = '' AND s.name GLOB '*' || c.class_name || '.*')
          OR (input.lifecycle_prefix != '' AND s.name GLOB input.lifecycle_prefix || c.class_name || '.*')
        )
        AND (
          s.name GLOB '*onCreate*' OR s.name GLOB '*onStart*' OR s.name GLOB '*onResume*'
          OR s.name GLOB '*onPause*' OR s.name GLOB '*onStop*'
          OR s.name GLOB '*onDestroy*' OR s.name GLOB '*onDestroyView*'
        )
      ORDER BY s.ts DESC
      LIMIT 1
    ) AS lifecycle_phase_at_sample
  FROM class_candidates c
),
suspect_classes AS (
  SELECT
    *,
    CASE
      WHEN lifecycle_phase_at_sample = 'destroyed' THEN 'destroyed_reachable'
      WHEN reachable_obj_count > 1 THEN 'multi_instance_reachable'
      ELSE 'not_suspect'
    END AS leak_state
  FROM candidate_states
  WHERE lifecycle_phase_at_sample = 'destroyed'
    OR reachable_obj_count > 1
  ORDER BY
    CASE WHEN lifecycle_phase_at_sample = 'destroyed' THEN 0 ELSE 1 END,
    self_size_bytes DESC,
    reachable_obj_count DESC
  LIMIT (SELECT max_candidates FROM input)
),
suspect_objects AS (
  SELECT
    h.*,
    s.leak_state
  FROM heap_objects h
  JOIN suspect_classes s
    ON s.upid = h.upid
    AND s.graph_sample_ts = h.graph_sample_ts
    AND s.class_name = h.class_name
)
SELECT
  so.process_name,
  printf('%d', so.graph_sample_ts) AS graph_sample_ts,
  so.class_name AS candidate_class,
  so.object_id AS owned_object_id,
  COALESCE(owner_class.deobfuscated_name, owner_class.name, printf('owner:%d', ref.owner_id)) AS owner_class,
  COALESCE(CASE
    WHEN ref.deobfuscated_field_name IS NOT NULL AND ref.deobfuscated_field_name != ref.field_name THEN ref.deobfuscated_field_name
    ELSE ref.field_name
  END, '<unknown>') AS field_display,
  ref.field_type_name,
  so.leak_state
FROM suspect_objects so
JOIN heap_graph_reference ref
  ON ref.owned_id = so.object_id
  AND ref.id NOT IN _excluded_refs
JOIN heap_graph_object owner_obj
  ON owner_obj.id = ref.owner_id
  AND owner_obj.reachable = 1
LEFT JOIN heap_graph_class owner_class ON owner_obj.type_id = owner_class.id
WHERE ref.owner_id IS NOT NULL
ORDER BY
  CASE so.leak_state WHEN 'destroyed_reachable' THEN 0 ELSE 1 END,
  so.class_name,
  so.object_id
LIMIT (SELECT max_reference_edges FROM input)
