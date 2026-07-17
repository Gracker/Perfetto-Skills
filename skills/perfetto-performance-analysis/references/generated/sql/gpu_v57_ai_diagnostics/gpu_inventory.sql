-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/gpu_v57_ai_diagnostics.skill.yaml
-- Source SHA-256: ac78ea2ed81bd2cff026d28c2ff54159ddd20e792fccc6cbd00171f1b18c6a36
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

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
