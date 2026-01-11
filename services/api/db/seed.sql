-- Brands
INSERT INTO brands (name, slug, website_url)
VALUES
  ('Acme Pet Nutrition', 'acme', NULL),
  ('GoodPaws', 'goodpaws', NULL)
ON CONFLICT DO NOTHING;

-- Canonical ingredients
INSERT INTO ingredient_canonical (name, slug, kind)
VALUES
  ('Chicken', 'chicken', 'ingredient'),
  ('Beef', 'beef', 'ingredient'),
  ('Poultry', 'poultry', 'allergen_category'),
  ('Rice', 'rice', 'ingredient'),
  ('Pea protein', 'pea-protein', 'ingredient'),
  ('Salmon', 'salmon', 'ingredient')
ON CONFLICT DO NOTHING;

-- Hierarchy: Poultry -> Chicken
INSERT INTO ingredient_hierarchy (parent_id, child_id, relation_type)
SELECT p.id, c.id, 'is_a'
FROM ingredient_canonical p, ingredient_canonical c
WHERE p.slug='poultry' AND c.slug='chicken'
ON CONFLICT DO NOTHING;

-- Synonyms
INSERT INTO ingredient_synonyms (canonical_id, synonym, match_type)
SELECT id, 'chicken meal', 'contains' FROM ingredient_canonical WHERE slug='chicken'
ON CONFLICT DO NOTHING;

INSERT INTO ingredient_synonyms (canonical_id, synonym, match_type)
SELECT id, 'pea protein isolate', 'contains' FROM ingredient_canonical WHERE slug='pea-protein'
ON CONFLICT DO NOTHING;

-- Products
WITH b AS (SELECT id, slug FROM brands)
INSERT INTO products (brand_id, name, slug, species, format, life_stage)
SELECT b.id, 'Chicken & Rice Adult Dry', 'acme-chicken-rice-adult-dry', 'dog', 'dry', 'adult'
FROM b WHERE b.slug='acme'
ON CONFLICT DO NOTHING;

WITH b AS (SELECT id, slug FROM brands)
INSERT INTO products (brand_id, name, slug, species, format, life_stage)
SELECT b.id, 'Salmon & Rice Adult Dry', 'goodpaws-salmon-rice-adult-dry', 'dog', 'dry', 'adult'
FROM b WHERE b.slug='goodpaws'
ON CONFLICT DO NOTHING;

-- Ingredient list versions
WITH p AS (SELECT id, slug FROM products)
INSERT INTO product_ingredient_lists (product_id, version, source_type)
SELECT p.id, 1, 'manual' FROM p
ON CONFLICT DO NOTHING;

-- Ingredient items
WITH
  p AS (SELECT id, slug FROM products),
  l AS (
    SELECT il.id, p.slug AS product_slug
    FROM product_ingredient_lists il
    JOIN p ON p.id = il.product_id
    WHERE il.version = 1
  )
INSERT INTO product_ingredient_items (ingredient_list_id, raw_text, order_index, is_may_contain, is_trace)
SELECT l.id, x.raw_text, x.order_index, false, false
FROM l
JOIN (
  VALUES
    ('acme-chicken-rice-adult-dry', 0, 'Chicken meal'),
    ('acme-chicken-rice-adult-dry', 1, 'Rice'),
    ('acme-chicken-rice-adult-dry', 2, 'Pea protein'),

    ('goodpaws-salmon-rice-adult-dry', 0, 'Salmon'),
    ('goodpaws-salmon-rice-adult-dry', 1, 'Rice'),
    ('goodpaws-salmon-rice-adult-dry', 2, 'Pea protein isolate')
) AS x(product_slug, order_index, raw_text)
ON x.product_slug = l.product_slug
ON CONFLICT DO NOTHING;
