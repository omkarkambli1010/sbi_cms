-- ============================================================================
-- 017_content_tables.sql — generic content for the inner pages.
--
-- The home folds each have their own tables because their shapes differ and
-- were designed one at a time. About, Leadership and Sector are ~20 more
-- entities; giving each a table and seven routines would be ~140 functions
-- that differ only in column names. Two tables carry them instead:
--
--   content_blocks  one JSON object per section — the section's own fields
--                   (title, labels, button text …)
--   content_items   rows of a named collection inside a section — the list
--                   entries (a value card, an award, a leader …)
--
-- Fields live in `data`. That does NOT make them unvalidated: the field list,
-- kinds, limits and required flags for every section are in the registry the
-- Go API validates against, so nothing reaches `data` that a screen could not
-- have produced. The database still enforces what it can — `data` is a JSON
-- object, bounded in size, and the parent section exists.
--
-- Media is referenced by id under a key ending `_media` (e.g. `photo_media`).
-- The public payload swaps those ids for {url, alt, width, height}, and
-- cms.media_usage reports them, so an image used here cannot be deleted from
-- the library out from under a page.
-- ============================================================================

SET search_path = cms, public;

CREATE TABLE IF NOT EXISTS cms.content_blocks (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  section_id BIGINT NOT NULL UNIQUE REFERENCES cms.page_sections (id) ON DELETE CASCADE,
  data       JSONB  NOT NULL DEFAULT '{}'::jsonb
             CONSTRAINT content_blocks_data_object CHECK (jsonb_typeof(data) = 'object'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS content_blocks_touch ON cms.content_blocks;
CREATE TRIGGER content_blocks_touch BEFORE UPDATE ON cms.content_blocks
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

CREATE TABLE IF NOT EXISTS cms.content_items (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  section_id    BIGINT NOT NULL REFERENCES cms.page_sections (id) ON DELETE CASCADE,
  /* The registry's collection key: 'values', 'awards', 'leaders' … */
  collection    TEXT   NOT NULL CONSTRAINT content_items_collection_shape CHECK (collection ~ '^[a-z][a-z0-9-]*$'),
  /* A stable handle the site can look a row up by (a slug, 'board', 'nse') —
     reordering must never change what an editor's row means. Optional. */
  item_key      TEXT   CONSTRAINT content_items_key_shape CHECK (item_key IS NULL OR item_key ~ '^[a-z0-9][a-z0-9-]*$'),
  data          JSONB  NOT NULL DEFAULT '{}'::jsonb
                CONSTRAINT content_items_data_object CHECK (jsonb_typeof(data) = 'object'),
  display_order INTEGER NOT NULL DEFAULT 0,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS content_items_section_collection_order_idx
  ON cms.content_items (section_id, collection, display_order);

/* A key identifies a row inside its collection. NULL keys are not compared. */
CREATE UNIQUE INDEX IF NOT EXISTS content_items_key_unique
  ON cms.content_items (section_id, collection, item_key)
  WHERE item_key IS NOT NULL;

DROP TRIGGER IF EXISTS content_items_touch ON cms.content_items;
CREATE TRIGGER content_items_touch BEFORE UPDATE ON cms.content_items
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();
