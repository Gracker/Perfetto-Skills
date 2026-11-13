-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/rendering_pipeline_detection.skill.yaml
-- Source SHA-256: bdb32cee14ce0f8f258001d34bdb35cc39cc71fb98757a956e28b913c1064b73

WITH
      pipeline_scores AS (
        SELECT * FROM ${pipeline_scores}
      ),
      pipeline_metadata(
        pipeline_id,
        rendering_type_id,
        primary_eligible,
        feature_visible,
        doc_path
      ) AS (
        VALUES
        ('ANDROID_PIP_FREEFORM', NULL, 0, 1, 'references/generated/knowledge/rendering-teaching.md#s06_multi_window'),
        ('ANDROID_VIEW_MIXED', 'S05_MIXED_RENDERING', 1, 0, 'references/generated/knowledge/rendering-teaching.md#s05_mixed_rendering'),
        ('ANDROID_VIEW_MULTI_WINDOW', NULL, 0, 1, 'references/generated/knowledge/rendering-teaching.md#s06_multi_window'),
        ('ANDROID_VIEW_SOFTWARE', 'S07_SOFTWARE_OFFSCREEN', 1, 0, 'references/generated/knowledge/rendering-teaching.md#s07_software_offscreen'),
        ('ANDROID_VIEW_STANDARD_BLAST', 'S02_AOSP_STANDARD', 1, 0, 'references/generated/knowledge/rendering-teaching.md#s02_aosp_standard'),
        ('ANDROID_VIEW_STANDARD_LEGACY', 'S02_AOSP_STANDARD', 1, 0, 'references/generated/knowledge/rendering-teaching.md#s02_aosp_standard'),
        ('ANGLE_GLES_VULKAN', NULL, 0, 1, 'references/generated/knowledge/rendering-teaching.md#s08_native_graphics'),
        ('CAMERA_PIPELINE', 'S11_CAMERA', 1, 0, 'references/generated/knowledge/rendering-teaching.md#s11_camera'),
        ('CHROME_BROWSER_VIZ', 'S16_CHROMIUM_BROWSER', 1, 0, 'references/generated/knowledge/rendering-teaching.md#s16_chromium_browser'),
        ('COMPOSE_STANDARD', 'S02_AOSP_STANDARD', 1, 0, 'references/generated/knowledge/rendering-teaching.md#s02_aosp_standard'),
        ('FLUTTER_SURFACEVIEW_IMPELLER', 'S10_FLUTTER', 1, 0, 'references/generated/knowledge/rendering-teaching.md#s10_flutter'),
        ('FLUTTER_SURFACEVIEW_SKIA', 'S10_FLUTTER', 1, 0, 'references/generated/knowledge/rendering-teaching.md#s10_flutter'),
        ('FLUTTER_TEXTUREVIEW', 'S10_FLUTTER', 1, 0, 'references/generated/knowledge/rendering-teaching.md#s10_flutter'),
        ('GAME_ENGINE', 'S13_GAME', 1, 0, 'references/generated/knowledge/rendering-teaching.md#s13_game'),
        ('HARDWARE_BUFFER_RENDERER', NULL, 0, 1, 'references/generated/knowledge/rendering-teaching.md#s07_software_offscreen'),
        ('IMAGEREADER_PIPELINE', NULL, 0, 1, 'references/generated/knowledge/rendering-teaching.md#s07_software_offscreen'),
        ('OPENGL_ES', 'S08_NATIVE_GRAPHICS', 1, 0, 'references/generated/knowledge/rendering-teaching.md#s08_native_graphics'),
        ('RN_NEW_ARCH_HWUI', 'S14_REACT_NATIVE', 1, 0, 'references/generated/knowledge/rendering-teaching.md#s14_react_native'),
        ('RN_OLD_ARCH_HWUI', 'S14_REACT_NATIVE', 1, 0, 'references/generated/knowledge/rendering-teaching.md#s14_react_native'),
        ('RN_SKIA_RENDERER', 'S14_REACT_NATIVE', 1, 0, 'references/generated/knowledge/rendering-teaching.md#s14_react_native'),
        ('SOFTWARE_COMPOSITING', NULL, 0, 1, 'references/generated/knowledge/rendering-teaching.md#s01_overview'),
        ('SURFACE_CONTROL_API', NULL, 0, 1, 'references/generated/knowledge/rendering-teaching.md#s07_software_offscreen'),
        ('SURFACEVIEW_BLAST', 'S03_SURFACEVIEW', 1, 0, 'references/generated/knowledge/rendering-teaching.md#s03_surfaceview'),
        ('TEXTUREVIEW_STANDARD', 'S04_TEXTUREVIEW', 1, 0, 'references/generated/knowledge/rendering-teaching.md#s04_textureview'),
        ('VARIABLE_REFRESH_RATE', NULL, 0, 1, 'references/generated/knowledge/rendering-teaching.md#s01_overview'),
        ('VIDEO_OVERLAY_HWC', NULL, 0, 1, 'references/generated/knowledge/rendering-teaching.md#s12_video_overlay_hwc'),
        ('VULKAN_NATIVE', 'S08_NATIVE_GRAPHICS', 1, 0, 'references/generated/knowledge/rendering-teaching.md#s08_native_graphics'),
        ('WEBVIEW_GL_FUNCTOR', 'S09_WEBVIEW', 1, 0, 'references/generated/knowledge/rendering-teaching.md#s09_webview'),
        ('WEBVIEW_SURFACE_CONTROL', 'S09_WEBVIEW', 1, 0, 'references/generated/knowledge/rendering-teaching.md#s09_webview'),
        ('WEBVIEW_SURFACEVIEW_WRAPPER', 'S09_WEBVIEW', 1, 0, 'references/generated/knowledge/rendering-teaching.md#s09_webview'),
        ('WEBVIEW_TEXTUREVIEW_CUSTOM', 'S09_WEBVIEW', 1, 0, 'references/generated/knowledge/rendering-teaching.md#s09_webview')
      ),
      pipeline_related_rendering_types(
        pipeline_id,
        rendering_type_id
      ) AS (
        VALUES
        ('ANDROID_PIP_FREEFORM', 'S06_MULTI_WINDOW'),
        ('ANDROID_VIEW_MULTI_WINDOW', 'S06_MULTI_WINDOW'),
        ('ANGLE_GLES_VULKAN', 'S08_NATIVE_GRAPHICS'),
        ('HARDWARE_BUFFER_RENDERER', 'S07_SOFTWARE_OFFSCREEN'),
        ('IMAGEREADER_PIPELINE', 'S07_SOFTWARE_OFFSCREEN'),
        ('SURFACE_CONTROL_API', 'S07_SOFTWARE_OFFSCREEN'),
        ('VIDEO_OVERLAY_HWC', 'S12_VIDEO_OVERLAY_HWC')
      ),
      ranked AS (
        SELECT
          ps.pipeline_id,
          ps.score,
          pm.rendering_type_id,
          ROW_NUMBER() OVER (ORDER BY ps.score DESC, ps.pipeline_id ASC) as rank
        FROM pipeline_scores ps
        JOIN pipeline_metadata pm USING (pipeline_id)
        WHERE ps.score >= 0.3
          AND pm.primary_eligible = 1
      ),
      primary_pipeline AS (
        SELECT pipeline_id, rendering_type_id, score FROM ranked WHERE rank = 1
      ),
      candidates AS (
        SELECT pipeline_id, rendering_type_id, score, rank
        FROM ranked
        WHERE rank <= 5
      ),
      features AS (
        SELECT
          ps.pipeline_id,
          ps.score,
          ROW_NUMBER() OVER (ORDER BY ps.score DESC, ps.pipeline_id ASC) as rank
        FROM pipeline_scores ps
        JOIN pipeline_metadata pm USING (pipeline_id)
        WHERE pm.feature_visible = 1
          AND ps.score >= 0.3
      ),
      rendering_type_scores AS (
        SELECT
          rendering_type_id,
          MAX(score) as score
        FROM ranked
        WHERE rendering_type_id IS NOT NULL
        GROUP BY rendering_type_id
      ),
      ranked_rendering_types AS (
        SELECT
          rendering_type_id,
          score,
          ROW_NUMBER() OVER (ORDER BY score DESC, rendering_type_id ASC) as rank
        FROM rendering_type_scores
      ),
      related_rendering_type_scores AS (
        SELECT
          prt.rendering_type_id,
          MAX(f.score) as score
        FROM features f
        JOIN pipeline_related_rendering_types prt USING (pipeline_id)
        GROUP BY prt.rendering_type_id
      ),
      ranked_related_rendering_types AS (
        SELECT
          rendering_type_id,
          score,
          ROW_NUMBER() OVER (ORDER BY score DESC, rendering_type_id ASC) as rank
        FROM related_rendering_type_scores
      ),
      candidate_list AS (
        SELECT GROUP_CONCAT(pipeline_id || ':' || ROUND(score, 2), ',') as candidates_list
        FROM (
          SELECT pipeline_id, score
          FROM candidates
          ORDER BY rank ASC
        )
        GROUP BY 'all_candidates'
      ),
      rendering_type_candidate_list AS (
        SELECT GROUP_CONCAT(rendering_type_id || ':' || ROUND(score, 2), ',') as rendering_type_candidates_list
        FROM (
          SELECT rendering_type_id, score
          FROM ranked_rendering_types
          WHERE rank <= 5
          ORDER BY rank ASC
        )
        GROUP BY 'all_rendering_type_candidates'
      ),
      related_rendering_type_candidate_list AS (
        SELECT GROUP_CONCAT(rendering_type_id || ':' || ROUND(score, 2), ',') as related_rendering_type_candidates_list
        FROM (
          SELECT rendering_type_id, score
          FROM ranked_related_rendering_types
          WHERE rank <= 5
          ORDER BY rank ASC
        )
        GROUP BY 'all_related_rendering_type_candidates'
      ),
      feature_list AS (
        SELECT GROUP_CONCAT(pipeline_id || ':' || ROUND(score, 2), ',') as features_list
        FROM (
          SELECT pipeline_id, score
          FROM features
          ORDER BY rank ASC
        )
        GROUP BY 'all_features'
      ),
      result AS (
        SELECT
          COALESCE((SELECT pipeline_id FROM primary_pipeline), 'ANDROID_VIEW_STANDARD_BLAST') as primary_pipeline_id,
          COALESCE((SELECT rendering_type_id FROM primary_pipeline), 'S02_AOSP_STANDARD') as primary_rendering_type_id,
          COALESCE((SELECT score FROM primary_pipeline), 0.50) as primary_confidence,
          COALESCE((SELECT candidates_list FROM candidate_list), '') as candidates_list,
          COALESCE((SELECT rendering_type_candidates_list FROM rendering_type_candidate_list), '') as rendering_type_candidates_list,
          COALESCE((SELECT related_rendering_type_candidates_list FROM related_rendering_type_candidate_list), '') as related_rendering_type_candidates_list,
          COALESCE((SELECT features_list FROM feature_list), '') as features_list
      )
      SELECT
        r.primary_pipeline_id,
        r.primary_rendering_type_id,
        r.primary_confidence,
        r.candidates_list,
        r.rendering_type_candidates_list,
        r.related_rendering_type_candidates_list,
        r.features_list,
        COALESCE((SELECT doc_path FROM pipeline_metadata WHERE pipeline_id = r.primary_pipeline_id), 'references/generated/knowledge/rendering-teaching.md#s02_aosp_standard') as doc_path
      FROM result r
