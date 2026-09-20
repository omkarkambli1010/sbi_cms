-- ============================================================================
-- 014_nav_tree.sql — make the navigation tree editable, not just storable.
--
-- navigation_items has always had parent_id, and cms.nav_children recurses, so
-- a nested menu already renders — the seeded footer is two levels deep. What
-- was missing was the ability to *change* the shape:
--
--   1. cms.nav_item_update takes label, href, icon and new-tab. It cannot
--      re-parent, so an item could be born under a parent but never moved
--      under one afterwards.
--
--   2. cms.nav_item_reorder renumbered every row in the menu from 1..n,
--      ignoring depth — while nav_item_create numbers within a parent. With
--      two levels the two disagreed and siblings interleaved.
--
-- Re-parenting is a new function rather than a parameter on nav_item_update,
-- because NULL is a meaningful parent_id — it means "top level" — so an
-- optional argument could not tell "leave it where it is" from "move it to
-- the top". A separate verb has no such ambiguity.
-- ============================================================================

SET search_path = cms, public;

-- ---------------------------------------------------------------------------
-- nav_item_move — re-parent one item
--
-- Guards, in order of how badly each would break the menu:
--
--   * A cycle. Making an item its own ancestor would hang nav_children in
--     infinite recursion the next time the public payload is built — every
--     marketing page down, from one dashboard drag.
--   * A different menu. The header's links cannot become the footer's.
--   * Itself as parent. 001 already has a CHECK for it; caught here too so
--     the editor gets a sentence rather than a constraint violation.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cms.nav_item_move(p_id BIGINT, p_parent_id BIGINT)
RETURNS cms.navigation_items
LANGUAGE plpgsql
AS $$
DECLARE
  v_row     cms.navigation_items;
  v_menu_id BIGINT;
  v_cursor  BIGINT;
  v_guard   INTEGER := 0;
  v_order   INTEGER;
BEGIN
  SELECT menu_id INTO v_menu_id FROM cms.navigation_items WHERE id = p_id;

  IF v_menu_id IS NULL THEN
    RAISE EXCEPTION 'Navigation item % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;

  IF p_parent_id IS NOT NULL THEN
    IF p_parent_id = p_id THEN
      RAISE EXCEPTION 'A link cannot be inside itself'
        USING ERRCODE = 'check_violation';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM cms.navigation_items
       WHERE id = p_parent_id AND menu_id = v_menu_id
    ) THEN
      RAISE EXCEPTION 'The chosen parent is not in the same menu'
        USING ERRCODE = 'foreign_key_violation';
    END IF;

    /* Walk up from the proposed parent. If we meet the item being moved, the
       move would close a loop. The counter is a belt-and-braces stop in case
       a cycle already exists in the data. */
    v_cursor := p_parent_id;

    WHILE v_cursor IS NOT NULL AND v_guard < 100 LOOP
      IF v_cursor = p_id THEN
        RAISE EXCEPTION 'That would put a link inside one of its own children'
          USING ERRCODE = 'check_violation';
      END IF;

      SELECT parent_id INTO v_cursor FROM cms.navigation_items WHERE id = v_cursor;
      v_guard := v_guard + 1;
    END LOOP;
  END IF;

  /* Land at the end of the destination level, the same rule nav_item_create
     follows, so a moved item does not silently jump to the front. */
  SELECT coalesce(max(display_order), 0) + 1 INTO v_order
    FROM cms.navigation_items
   WHERE menu_id = v_menu_id AND parent_id IS NOT DISTINCT FROM p_parent_id AND id <> p_id;

  UPDATE cms.navigation_items
     SET parent_id = p_parent_id, display_order = v_order
   WHERE id = p_id
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

-- ---------------------------------------------------------------------------
-- nav_item_reorder — one level at a time
--
-- Replaces 002's menu-wide version. p_parent_id NULL means the top level, so
-- the two-argument call the dashboard already makes keeps working and now
-- means what it looks like it means.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS cms.nav_item_reorder(TEXT, BIGINT[]);

CREATE OR REPLACE FUNCTION cms.nav_item_reorder(
  p_menu_key  TEXT,
  p_ids       BIGINT[],
  p_parent_id BIGINT DEFAULT NULL
)
RETURNS SETOF cms.navigation_items
LANGUAGE plpgsql
AS $$
DECLARE
  v_menu_id BIGINT;
  v_actual  BIGINT;
BEGIN
  SELECT id INTO v_menu_id FROM cms.navigation_menus WHERE menu_key = btrim(p_menu_key);

  IF v_menu_id IS NULL THEN
    RAISE EXCEPTION 'Menu % not found', p_menu_key USING ERRCODE = 'no_data_found';
  END IF;

  -- Every id must be on this level of this menu.
  IF EXISTS (
    SELECT 1 FROM unnest(p_ids) AS t(id)
     WHERE NOT EXISTS (
       SELECT 1 FROM cms.navigation_items i
        WHERE i.id = t.id
          AND i.menu_id = v_menu_id
          AND i.parent_id IS NOT DISTINCT FROM p_parent_id
     )
  ) THEN
    RAISE EXCEPTION 'Reorder list contains a link that is not on this level of %', p_menu_key
      USING ERRCODE = 'foreign_key_violation';
  END IF;

  -- …and the level must contain nothing else, or a row would keep a stale
  -- position while its siblings were renumbered around it.
  SELECT count(*) INTO v_actual
    FROM cms.navigation_items
   WHERE menu_id = v_menu_id AND parent_id IS NOT DISTINCT FROM p_parent_id;

  IF v_actual <> coalesce(array_length(p_ids, 1), 0) THEN
    RAISE EXCEPTION 'Reorder list has % of the % links on this level',
      coalesce(array_length(p_ids, 1), 0), v_actual
      USING ERRCODE = 'foreign_key_violation';
  END IF;

  UPDATE cms.navigation_items i
     SET display_order = t.position
    FROM (SELECT id, ordinality::INTEGER AS position
            FROM unnest(p_ids) WITH ORDINALITY AS u(id, ordinality)) AS t
   WHERE i.id = t.id;

  RETURN QUERY
    SELECT * FROM cms.navigation_items
     WHERE menu_id = v_menu_id AND parent_id IS NOT DISTINCT FROM p_parent_id
     ORDER BY display_order, id;
END;
$$;
