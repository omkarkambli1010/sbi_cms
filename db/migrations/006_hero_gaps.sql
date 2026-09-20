-- ============================================================================
-- 006_hero_gaps.sql — the four hero operations 002 left out.
--
-- Every content entity is meant to expose the same seven operations. The hero
-- does not: 002 gave hero_rotating_lines a _get-less set, and hero_kpis no
-- _create, _get or _delete at all. The Hero dashboard screen needs all four,
-- and a set of operations that is complete for nineteen entities and short for
-- one is the kind of gap a screen discovers at runtime.
--
-- Nothing here changes an existing function; 002 is left exactly as applied.
-- ============================================================================

SET search_path = cms, public;

-- hero rotating lines --------------------------------------------------------

CREATE OR REPLACE FUNCTION cms.hero_line_get(p_id BIGINT)
RETURNS cms.hero_rotating_lines
LANGUAGE sql
STABLE
AS $$
  SELECT * FROM cms.hero_rotating_lines WHERE id = p_id;
$$;

-- hero KPIs ------------------------------------------------------------------

-- hero_kpi_list returns a projection that joins the icon URL, so _get matches
-- it rather than the bare table: a screen that edits a row it listed should
-- not have to ask for the media row separately to show the current icon.
CREATE OR REPLACE FUNCTION cms.hero_kpi_get(p_id BIGINT)
RETURNS TABLE (
  id            BIGINT,
  kpi_key       TEXT,
  kind          TEXT,
  value         TEXT,
  label         TEXT,
  icon_media_id BIGINT,
  icon_url      TEXT,
  display_order INTEGER,
  is_active     BOOLEAN
)
LANGUAGE sql
STABLE
AS $$
  SELECT k.id, k.kpi_key, k.kind, k.value, k.label, k.icon_media_id, m.url,
         k.display_order, k.is_active
    FROM cms.hero_kpis k
    LEFT JOIN cms.media_assets m ON m.id = k.icon_media_id
   WHERE k.id = p_id;
$$;

-- kpi_key and kind are creation-time decisions: the key is the stable handle
-- the public payload keys tiles by, and the kind selects the ornament the
-- component draws. hero_kpi_update deliberately edits neither, so both are
-- taken here.
CREATE OR REPLACE FUNCTION cms.hero_kpi_create(
  p_hero_id       BIGINT,
  p_kpi_key       TEXT,
  p_kind          TEXT,
  p_value         TEXT,
  p_label         TEXT,
  p_icon_media_id BIGINT DEFAULT NULL
)
RETURNS cms.hero_kpis
LANGUAGE plpgsql
AS $$
DECLARE
  v_order INTEGER;
  v_row   cms.hero_kpis;
BEGIN
  SELECT coalesce(max(display_order), 0) + 1 INTO v_order
    FROM cms.hero_kpis WHERE hero_id = p_hero_id;

  INSERT INTO cms.hero_kpis (hero_id, kpi_key, kind, value, label, icon_media_id, display_order)
  VALUES (
    p_hero_id,
    btrim(lower(p_kpi_key)),
    coalesce(nullif(btrim(p_kind), ''), 'value'),
    nullif(btrim(coalesce(p_value, '')), ''),
    btrim(p_label),
    p_icon_media_id,
    v_order
  )
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.hero_kpi_delete(p_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM cms.hero_kpis WHERE id = p_id;
  RETURN FOUND;
END;
$$;
