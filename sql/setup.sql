-- =====================================================================
-- Hybrid RAG Sales Agent - database setup (Supabase / PostgreSQL 15+)
-- Run this once in the Supabase SQL Editor.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Product catalogue (structured data -> answered with SQL)
-- ---------------------------------------------------------------------
create table if not exists public.products (
  product_id    integer primary key,
  product_name  text    not null,
  category      text    not null check (category in (
                  'Festive Lawn', 'Embroidered Chiffon', 'Silk Party Wear',
                  'Velvet Winter Collection', 'Heavy Net Bridal')),
  price_bdt     integer not null check (price_bdt > 0),
  availability  text    not null check (availability in ('In Stock', 'Low Stock', 'Out of Stock')),
  size_chart    text
);

-- Illustrative sample rows so the agent has something to query.
-- The live catalogue has 150 products; load your own with a CSV import.
insert into public.products (product_id, product_name, category, price_bdt, availability, size_chart) values
  (1,  'Maria Silk Party Wear - Vol 18',          'Silk Party Wear',          5300,  'In Stock',     'S, M, L, XL'),
  (2,  'Gulbahar Silk Party Wear - Vol 11',       'Silk Party Wear',          6300,  'In Stock',     'S, M, L, XL'),
  (3,  'Elan Silk Party Wear - Vol 5',            'Silk Party Wear',          13600, 'In Stock',     'S, M, L, XL'),
  (4,  'Zaha Velvet Winter Collection - Vol 18',  'Velvet Winter Collection', 5400,  'In Stock',     'S, M, L, XL'),
  (5,  'Nur Velvet Winter Collection - Vol 8',    'Velvet Winter Collection', 6700,  'Low Stock',    'S, M, L, XL'),
  (6,  'Sobia Velvet Winter Collection - Vol 13', 'Velvet Winter Collection', 14500, 'In Stock',     'S, M, L, XL'),
  (7,  'Zaha Festive Lawn - Vol 9',               'Festive Lawn',             3200,  'Out of Stock', 'Unstitched'),
  (8,  'Nur Embroidered Chiffon - Vol 13',        'Embroidered Chiffon',      8900,  'Out of Stock', 'S, M, L, XL'),
  (9,  'Maria Heavy Net Bridal - Vol 3',          'Heavy Net Bridal',         38000, 'Low Stock',    'S, M, L, XL'),
  (10, 'Asim Festive Lawn - Vol 11',              'Festive Lawn',             3600,  'Low Stock',    'Unstitched')
on conflict (product_id) do nothing;

-- ---------------------------------------------------------------------
-- 2. Read-only role for the AI agent's SQL tool
--    The model writes its own SQL, so it must never be able to change data.
--    Even "DROP TABLE products" from a prompt injection returns
--    "permission denied".
-- ---------------------------------------------------------------------
create role noorzaah_bot login password 'CHANGE_ME_TO_A_LONG_RANDOM_PASSWORD';
grant usage on schema public to noorzaah_bot;
grant select on public.products to noorzaah_bot;

alter table public.products enable row level security;
create policy "bot can read products"
  on public.products for select
  to noorzaah_bot
  using (true);

-- Lets the postgres user test the role with:  set role noorzaah_bot;
grant noorzaah_bot to postgres;

-- ---------------------------------------------------------------------
-- 3. Knowledge base (unstructured data -> answered with vector search)
-- ---------------------------------------------------------------------
create extension if not exists vector;

-- The embedding column is left untyped on purpose: gemini-embedding-001
-- returns 3072 dimensions, and an untyped column accepts it as-is.
create table if not exists public.documents (
  id        uuid primary key default gen_random_uuid(),
  content   text,
  metadata  jsonb,
  embedding vector
);

alter table public.documents enable row level security;
revoke all on public.documents from anon, authenticated;

-- ---------------------------------------------------------------------
-- 4. Chat memory
--    n8n's Postgres Chat Memory node creates this table automatically on
--    first use. Run these two lines after the first chat message, otherwise
--    the table is exposed through Supabase's public API.
-- ---------------------------------------------------------------------
-- alter table public.n8n_chat_histories enable row level security;
-- revoke all on public.n8n_chat_histories from anon, authenticated;

-- ---------------------------------------------------------------------
-- 5. Quick checks
-- ---------------------------------------------------------------------
-- set role noorzaah_bot;
-- select count(*) from public.products;   -- works
-- delete from public.products;            -- ERROR: permission denied
-- reset role;
