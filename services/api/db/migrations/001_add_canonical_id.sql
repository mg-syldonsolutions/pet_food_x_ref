ALTER TABLE product_ingredient_items
  ADD COLUMN IF NOT EXISTS canonical_id uuid NULL;

CREATE INDEX IF NOT EXISTS idx_pii_canonical_id
  ON product_ingredient_items (canonical_id);

CREATE INDEX IF NOT EXISTS idx_pii_ingredient_list_id
  ON product_ingredient_items (ingredient_list_id);
