-- ============================================================
--  いっくいっく 1Quick — みんなで共有モード セットアップ用 SQL
--  Supabase の「SQL Editor」に貼り付けて Run してください。
-- ============================================================

-- 1) 句テーブル ------------------------------------------------
create table if not exists public.haiku (
  id         uuid primary key default gen_random_uuid(),
  lines      jsonb not null,          -- ["上五","中七","下五"]
  yomis      jsonb,                   -- よみ（音数/類似計算用）。無ければ lines を使う
  vec        jsonb,                   -- 特徴ベクトル（無ければクライアントが再計算）
  rating     double precision not null default 1500,
  battles    integer not null default 0,
  created_at timestamptz not null default now()
);

-- 2) 新規投稿は必ず rating=1500 / battles=0 に固定（不正値の混入を防ぐ） -----
create or replace function public.haiku_defaults()
returns trigger language plpgsql as $$
begin
  new.rating := 1500;
  new.battles := 0;
  return new;
end; $$;

drop trigger if exists trg_haiku_defaults on public.haiku;
create trigger trg_haiku_defaults
  before insert on public.haiku
  for each row execute function public.haiku_defaults();

-- 3) 投票（Elo）をサーバー側で原子的に計算 -----------------------
--    勝者・敗者をid順にロックして同時アクセスでも壊れない/デッドロックしない
create or replace function public.vote(winner uuid, loser uuid)
returns table(winner_rating double precision, loser_rating double precision)
language plpgsql
security definer
set search_path = public
as $$
declare
  wr double precision;
  lr double precision;
  ea double precision;
  k  constant double precision := 32;
begin
  if winner = loser then
    raise exception 'winner and loser must differ';
  end if;
  -- 2行をid順でロック（デッドロック回避）
  perform 1 from public.haiku where id in (winner, loser) order by id for update;

  select rating into wr from public.haiku where id = winner;
  select rating into lr from public.haiku where id = loser;
  if wr is null or lr is null then
    raise exception 'haiku not found';
  end if;

  ea := 1.0 / (1.0 + power(10.0, (lr - wr) / 400.0));
  wr := wr + k * (1.0 - ea);
  lr := lr + k * (0.0 - (1.0 - ea));

  update public.haiku set rating = wr, battles = battles + 1 where id = winner;
  update public.haiku set rating = lr, battles = battles + 1 where id = loser;

  return query select wr, lr;
end; $$;

-- 4) 権限 / Row Level Security ---------------------------------
alter table public.haiku enable row level security;

-- だれでも読める
drop policy if exists haiku_read on public.haiku;
create policy haiku_read on public.haiku
  for select to anon, authenticated using (true);

-- だれでも投稿できる（rating はトリガで固定されるので安全）
drop policy if exists haiku_insert on public.haiku;
create policy haiku_insert on public.haiku
  for insert to anon, authenticated with check (true);

-- ※ UPDATE / DELETE のポリシーは作らない＝直接の改ざんは不可。
--    レート変更は vote() 関数経由（security definer）だけが行える。
grant execute on function public.vote(uuid, uuid) to anon, authenticated;

-- 5) サンプル12句（最初から句くらべが成立するように） -------------
insert into public.haiku (lines, yomis) values
  ('["さくらさく","かぜにのりゆく","はなびらや"]',     '["さくらさく","かぜにのりゆく","はなびらや"]'),
  ('["はるかぜや","こどもらかける","かよいみち"]',     '["はるかぜや","こどもらかける","かよいみち"]'),
  ('["ふうりんの","おとにふりむく","ゆうまぐれ"]',     '["ふうりんの","おとにふりむく","ゆうまぐれ"]'),
  ('["にゅうどうぐも","みあげてのびる","せのびかな"]', '["にゅうどうぐも","みあげてのびる","せのびかな"]'),
  ('["せみしぐれ","きのねにすわる","ひるさがり"]',     '["せみしぐれ","きのねにすわる","ひるさがり"]'),
  ('["あかとんぼ","ゆうひにとけて","きえにけり"]',     '["あかとんぼ","ゆうひにとけて","きえにけり"]'),
  ('["つきしろし","むしのこえだけ","のこるよる"]',     '["つきしろし","むしのこえだけ","のこるよる"]'),
  ('["もみじちる","みずにうかんで","ながれゆく"]',     '["もみじちる","みずにうかんで","ながれゆく"]'),
  ('["こたつから","でられぬねこと","ぼくふたり"]',     '["こたつから","でられぬねこと","ぼくふたり"]'),
  ('["きたかぜや","マフラーまいて","かけるみち"]',     '["きたかぜや","マフラーまいて","かけるみち"]'),
  ('["ゆきのよる","しずかにつもる","おとのなさ"]',     '["ゆきのよる","しずかにつもる","おとのなさ"]'),
  ('["はつひので","やまのはあかく","もえはじむ"]',     '["はつひので","やまのはあかく","もえはじむ"]');
