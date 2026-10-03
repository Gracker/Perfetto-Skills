-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_v57_ai_diagnostics.skill.yaml
-- Source SHA-256: cc0be719cf724cb2c0f128f806abaa4a1cd942f6381a0b8e28a83ca9c4a876ab

SELECT
  g.machine_id,
  CASE WHEN g.machine_id = 0 THEN 1 ELSE 0 END AS is_host,
  g.ugpu,
  g.gpu AS gpu_index,
  COALESCE(g.vendor, '') AS vendor,
  COALESCE(g.name, '') AS name,
  COALESCE(g.model, '') AS model,
  COALESCE(g.architecture, '') AS architecture,
  COALESCE(CAST(g.uuid AS TEXT), '') AS uuid,
  COALESCE(g.pci_bdf, '') AS pci_bdf
FROM gpu AS g
WHERE (${ugpu} IS NULL OR g.ugpu = ${ugpu})
ORDER BY g.machine_id, g.gpu
