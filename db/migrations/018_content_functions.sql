-- ============================================================================
-- 018_content_functions.sql — the only door to content_blocks / content_items.
--
-- Same boundary as every other routine: SECURITY DEFINER with a pinned
-- search_path (016 does not reach routines created after it, so each one says
-- so itself), no dynamic SQL built from input, and sizes bounded.
-- ============================================================================

SET search_path = cms, public;

/* One page's content fits in a few KB; 200 KB is a runaway paste, not content. */
CREATE OR REPLACE FUNCTION cms.content_check_data(p_data JSONB)
RETURNS JSONB
LANGUAGE plpgsql
IMMUTABLE
SECURITY DEFINER SET search_path = cms, public
AS $$
BEGIN
  IF p_data IS NULL OR jsonb_typeof(p_data) <> 'object' THEN
    RAISE EXCEPTION 'Content data must be a JSON object' USING ERRCODE = 'invalid_parameter_value';
  END IF;
  IF pg_column_size(p_data) > 204800 THEN
    RAISE EXCEPTION 'Content data is too large' USING ERRCODE = 'program_limit_exceeded';
  END IF;
  RETURN p_data;
END;
$$;

-- --------------------------------------------------------------------------
-- block (one per section)
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cms.content_block_get(p_page_slug TEXT, p_section_key TEXT)
RETURNS TABLE (section_id BIGINT, data JSONB)
LANGUAGE sql
STABLE
SECURITY DEFINER SET search_path = cms, public
AS $$
  SELECT s.id, coalesce(b.data, '{}'::jsonb)
    FROM cms.page_sections s
    JOIN cms.pages p ON p.id = s.page_id
    LEFT JOIN cms.content_blocks b ON b.section_id = s.id
   WHERE p.slug = btrim(p_page_slug) AND s.section_key = btrim(p_section_key);
$$;

CREATE OR REPLACE FUNCTION cms.content_block_update(p_page_slug TEXT, p_section_key TEXT, p_data JSONB)
RETURNS TABLE (section_id BIGINT, data JSONB)
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = cms, public
AS $$
#variable_conflict use_column
DECLARE
  v_section BIGINT := cms.section_id_for(p_page_slug, p_section_key);
BEGIN
  IF v_section IS NULL THEN
    RAISE EXCEPTION 'Section % does not exist on page %', p_section_key, p_page_slug
      USING ERRCODE = 'no_data_found';
  END IF;

  INSERT INTO cms.content_blocks (section_id, data)
  VALUES (v_section, cms.content_check_data(p_data))
  ON CONFLICT (section_id) DO UPDATE SET data = EXCLUDED.data;

  RETURN QUERY SELECT b.section_id, b.data FROM cms.content_blocks b WHERE b.section_id = v_section;
END;
$$;

-- --------------------------------------------------------------------------
-- items
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cms.content_item_list(
  p_section_id  BIGINT,
  p_collection  TEXT,
  p_only_active BOOLEAN DEFAULT FALSE
)
RETURNS SETOF cms.content_items
LANGUAGE sql
STABLE
SECURITY DEFINER SET search_path = cms, public
AS $$
  SELECT *
    FROM cms.content_items
   WHERE section_id = p_section_id
     AND collection = p_collection
     AND (NOT p_only_active OR is_active)
   ORDER BY display_order, id;
$$;

CREATE OR REPLACE FUNCTION cms.content_item_get(p_id BIGINT)
RETURNS SETOF cms.content_items
LANGUAGE sql
STABLE
SECURITY DEFINER SET search_path = cms, public
AS $$
  SELECT * FROM cms.content_items WHERE id = p_id;
$$;

CREATE OR REPLACE FUNCTION cms.content_item_create(
  p_section_id    BIGINT,
  p_collection    TEXT,
  p_item_key      TEXT,
  p_data          JSONB,
  p_display_order INTEGER DEFAULT NULL
)
RETURNS cms.content_items
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = cms, public
AS $$
DECLARE
  v_row cms.content_items;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM cms.page_sections WHERE id = p_section_id) THEN
    RAISE EXCEPTION 'Section % does not exist', p_section_id USING ERRCODE = 'foreign_key_violation';
  END IF;

  INSERT INTO cms.content_items (section_id, collection, item_key, data, display_order)
  VALUES (
    p_section_id,
    btrim(p_collection),
    nullif(btrim(coalesce(p_item_key, '')), ''),
    cms.content_check_data(p_data),
    coalesce(
      p_display_order,
      (SELECT coalesce(max(display_order), 0) + 1
         FROM cms.content_items
        WHERE section_id = p_section_id AND collection = btrim(p_collection))
    )
  )
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.content_item_update(p_id BIGINT, p_item_key TEXT, p_data JSONB)
RETURNS cms.content_items
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = cms, public
AS $$
DECLARE
  v_row cms.content_items;
BEGIN
  UPDATE cms.content_items
     SET item_key = nullif(btrim(coalesce(p_item_key, '')), ''),
         data     = cms.content_check_data(p_data)
   WHERE id = p_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Content item % does not exist', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.content_item_delete(p_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = cms, public
AS $$
BEGIN
  DELETE FROM cms.content_items WHERE id = p_id;
  RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION cms.content_item_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.content_items
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = cms, public
AS $$
DECLARE
  v_row cms.content_items;
BEGIN
  UPDATE cms.content_items SET is_active = coalesce(p_is_active, FALSE)
   WHERE id = p_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Content item % does not exist', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

/* Same contract as cms.reorder_rows, scoped to one collection of one section:
   the list must be exactly the collection's current id set, so a stale
   dashboard cannot renumber half of it. */
CREATE OR REPLACE FUNCTION cms.content_item_reorder(
  p_section_id BIGINT,
  p_collection TEXT,
  p_ids        BIGINT[]
)
RETURNS SETOF cms.content_items
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = cms, public
AS $$
DECLARE
  v_expected BIGINT;
  v_given    BIGINT;
BEGIN
  IF p_ids IS NOT NULL AND array_length(p_ids, 1) IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM unnest(p_ids) AS t(id) GROUP BY t.id HAVING count(*) > 1) THEN
      RAISE EXCEPTION 'Reorder list contains the same id twice' USING ERRCODE = 'unique_violation';
    END IF;

    SELECT count(*) INTO v_expected FROM cms.content_items
     WHERE section_id = p_section_id AND collection = p_collection;
    SELECT count(*) INTO v_given FROM cms.content_items
     WHERE section_id = p_section_id AND collection = p_collection AND id = ANY (p_ids);

    IF v_given <> array_length(p_ids, 1) THEN
      RAISE EXCEPTION 'Reorder list contains a row that does not belong to this collection'
        USING ERRCODE = 'foreign_key_violation';
    END IF;
    IF v_expected <> array_length(p_ids, 1) THEN
      RAISE EXCEPTION 'Reorder list is incomplete: the collection has % rows, % were given',
        v_expected, array_length(p_ids, 1) USING ERRCODE = 'cardinality_violation';
    END IF;

    UPDATE cms.content_items AS r SET display_order = t.position
      FROM (SELECT id, ordinality::INTEGER AS position
              FROM unnest(p_ids) WITH ORDINALITY AS u(id, ordinality)) AS t
     WHERE r.id = t.id;
  END IF;

  RETURN QUERY SELECT * FROM cms.content_item_list(p_section_id, p_collection, FALSE);
END;
$$;
