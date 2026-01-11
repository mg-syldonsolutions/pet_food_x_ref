-- Enable UUID generation (Aurora Postgres typically supports pgcrypto)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------- Enums ----------
DO $$ BEGIN
  CREATE TYPE species AS ENUM ('dog','cat');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE product_format AS ENUM ('dry','wet','freeze_dried','raw','treat','supplement','other');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE life_stage AS ENUM ('puppy','adult','senior','all');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE condition_type AS ENUM ('symptom','suspected_allergen','confirmed_allergen');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE outcome AS ENUM ('improved','no_change','worsened','unknown');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE symptom_code AS ENUM (
    'ITCHING','EAR_INFECTIONS','HOT_SPOTS','HAIR_LOSS','REDNESS','PAW_LICKING',
    'VOMITING','DIARRHEA','GAS','SOFT_STOOL','CONSTIPATION','LOSS_OF_APPETITE',
    'WEIGHT_LOSS','LETHARGY'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE ingredient_kind AS ENUM ('ingredient','allergen_category');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE source_type AS ENUM ('manual','manufacturer_site','open_food_facts','photo_label');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE synonym_match_type AS ENUM ('exact','contains','regex');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ---------- Catalog ----------
CREATE TABLE IF NOT EXISTS brands (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  slug text NOT NULL UNIQUE,
  website_url text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  brand_id uuid NOT NULL REFERENCES brands(id),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  species species NOT NULL,
  format product_format NOT NULL,
  life_stage life_stage NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_products_brand_species ON products(brand_id, species);
CREATE INDEX IF NOT EXISTS idx_products_species_format_stage ON products(species, format, life_stage);

CREATE TABLE IF NOT EXISTS product_ingredient_lists (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  version int NOT NULL,
  effective_date date NULL,
  source_type source_type NOT NULL DEFAULT 'manual',
  source_ref text NULL,
  notes text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(product_id, version)
);

CREATE INDEX IF NOT EXISTS idx_ingredient_lists_latest ON product_ingredient_lists(product_id, version DESC);

CREATE TABLE IF NOT EXISTS product_ingredient_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ingredient_list_id uuid NOT NULL REFERENCES product_ingredient_lists(id) ON DELETE CASCADE,
  raw_text text NOT NULL,
  order_index int NOT NULL,
  is_may_contain boolean NOT NULL DEFAULT false,
  is_trace boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_items_list_order ON product_ingredient_items(ingredient_list_id, order_index);

-- ---------- Taxonomy ----------
CREATE TABLE IF NOT EXISTS ingredient_canonical (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  slug text NOT NULL UNIQUE,
  kind ingredient_kind NOT NULL DEFAULT 'ingredient',
  description text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ingredient_synonyms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  canonical_id uuid NOT NULL REFERENCES ingredient_canonical(id) ON DELETE CASCADE,
  synonym text NOT NULL,
  match_type synonym_match_type NOT NULL DEFAULT 'exact',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_synonyms_canonical ON ingredient_synonyms(canonical_id);

CREATE TABLE IF NOT EXISTS ingredient_hierarchy (
  parent_id uuid NOT NULL REFERENCES ingredient_canonical(id) ON DELETE CASCADE,
  child_id uuid NOT NULL REFERENCES ingredient_canonical(id) ON DELETE CASCADE,
  relation_type text NULL,
  PRIMARY KEY(parent_id, child_id)
);

CREATE INDEX IF NOT EXISTS idx_hierarchy_child ON ingredient_hierarchy(child_id);

-- Optional: cache raw item -> canonical mapping
CREATE TABLE IF NOT EXISTS ingredient_item_canonical_map (
  ingredient_item_id uuid PRIMARY KEY REFERENCES product_ingredient_items(id) ON DELETE CASCADE,
  canonical_id uuid NOT NULL REFERENCES ingredient_canonical(id),
  match_confidence smallint NOT NULL DEFAULT 100,
  matched_by text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_itemmap_canonical ON ingredient_item_canonical_map(canonical_id);

-- ---------- Users / Pets (later, but create now) ----------
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cognito_sub text NOT NULL UNIQUE,
  email text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name text NOT NULL,
  species species NOT NULL,
  age_years numeric(4,2) NOT NULL,
  breed text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pets_user ON pets(user_id);

CREATE TABLE IF NOT EXISTS pet_conditions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id uuid NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  condition_type condition_type NOT NULL,
  symptom_code symptom_code NULL,
  canonical_id uuid NULL REFERENCES ingredient_canonical(id),
  severity smallint NULL CHECK (severity BETWEEN 1 AND 5),
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (
    (condition_type = 'symptom' AND symptom_code IS NOT NULL AND canonical_id IS NULL)
    OR
    (condition_type IN ('suspected_allergen','confirmed_allergen') AND canonical_id IS NOT NULL AND symptom_code IS NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_conditions_pet_type ON pet_conditions(pet_id, condition_type);
CREATE INDEX IF NOT EXISTS idx_conditions_canonical ON pet_conditions(canonical_id);

CREATE TABLE IF NOT EXISTS pet_food_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pet_id uuid NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES products(id),
  started_on date NULL,
  ended_on date NULL,
  outcome outcome NOT NULL,
  notes text NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_food_events_pet_created ON pet_food_events(pet_id, created_at DESC);
