-- Ballonalarm: Bestenliste für den Online-Modus
-- Einmal im Supabase-Dashboard unter "SQL Editor" ausführen (oder als Migration).
--
-- Wie es funktioniert:
-- * Kein Login nötig. Jedes Gerät erzeugt beim ersten Start eine zufällige
--   Spieler-ID und einen geheimen Spieler-Schlüssel (bleibt im Browser).
-- * Der Server speichert nur einen Hash des Schlüssels. Wer den Schlüssel
--   nicht kennt, kann für diese Spieler-ID nichts eintragen.
-- * Lesen darf jeder, schreiben nur über die Funktion submit_result(),
--   die Treffer/min selbst ausrechnet und unsinnige Werte ablehnt.

create extension if not exists pgcrypto with schema extensions;

-- Spieler und Hash ihres Schlüssels: über die API weder lesbar noch schreibbar
create table if not exists public.players (
  player_id  uuid primary key,
  token_hash text not null,
  created_at timestamptz not null default now()
);
alter table public.players enable row level security;
revoke all on public.players from anon, authenticated;

create table if not exists public.scores (
  player_id   uuid primary key references public.players (player_id) on delete cascade,
  name        text        not null check (char_length(name) between 1 and 20),
  hpm         numeric(6,1) not null default 0,   -- Treffer pro Minute (beste Runde)
  spm         numeric(6,1) not null default 0,   -- Schüsse pro Minute (beste Runde)
  acc         integer     not null default 0,    -- Trefferquote in % (beste Runde)
  hits        integer     not null default 0,
  shots       integer     not null default 0,
  best_score  integer     not null default 0,
  games       integer     not null default 0,
  total_hits  integer     not null default 0,
  total_shots integer     not null default 0,
  total_secs  integer     not null default 0,
  updated_at  timestamptz not null default now()
);
create index if not exists scores_hpm_idx on public.scores (hpm desc);

alter table public.scores enable row level security;
drop policy if exists "Bestenliste ist öffentlich lesbar" on public.scores;
create policy "Bestenliste ist öffentlich lesbar" on public.scores
  for select to anon, authenticated using (true);
revoke insert, update, delete, truncate on public.scores from anon, authenticated;
grant select on public.scores to anon, authenticated;

create or replace function public.submit_result(
  p_player uuid, p_token text, p_name text,
  p_hits integer, p_shots integer, p_secs integer, p_score integer
) returns public.scores
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_hash text;
  v_name text := left(btrim(coalesce(p_name, '')), 20);
  v_hpm  numeric;
  v_spm  numeric;
  v_acc  integer;
  r      public.scores;
begin
  if p_player is null or p_token is null or char_length(p_token) not between 32 and 128 then
    raise exception 'invalid player';
  end if;
  -- Plausibilitätsprüfung: Runde 20 s bis 10 min, max. 8 Schüsse pro Sekunde,
  -- nie mehr Treffer als doppelt so viele wie Schüsse (Doppeltreffer).
  if p_secs < 20 or p_secs > 600
     or p_shots < 0 or p_shots > p_secs * 8
     or p_hits < 0 or p_hits > p_shots * 2
     or p_score < 0 or p_score > 100000 then
    raise exception 'invalid result';
  end if;

  -- Erster Eintrag legt den Spieler an, danach muss der Schlüssel passen.
  v_hash := encode(digest(p_token, 'sha256'), 'hex');
  insert into public.players (player_id, token_hash) values (p_player, v_hash)
    on conflict (player_id) do nothing;
  if not exists (select 1 from public.players where player_id = p_player and token_hash = v_hash) then
    raise exception 'invalid player';
  end if;
  -- Schutz gegen Spam: höchstens ein Ergebnis alle 15 Sekunden pro Spieler.
  if exists (select 1 from public.scores where player_id = p_player and updated_at > now() - interval '15 seconds') then
    raise exception 'too many submissions';
  end if;

  if v_name = '' then v_name := 'Anonym'; end if;
  v_hpm := round(p_hits / (p_secs / 60.0), 1);
  v_spm := round(p_shots / (p_secs / 60.0), 1);
  v_acc := case when p_shots > 0 then round(100.0 * least(p_hits, p_shots) / p_shots) else 0 end;

  insert into public.scores as s
    (player_id, name, hpm, spm, acc, hits, shots, best_score, games, total_hits, total_shots, total_secs, updated_at)
  values
    (p_player, v_name, v_hpm, v_spm, v_acc, p_hits, p_shots, p_score, 1, p_hits, p_shots, p_secs, now())
  on conflict (player_id) do update set
    name        = excluded.name,
    hpm         = greatest(s.hpm, excluded.hpm),
    spm         = case when excluded.hpm > s.hpm then excluded.spm   else s.spm   end,
    acc         = case when excluded.hpm > s.hpm then excluded.acc   else s.acc   end,
    hits        = case when excluded.hpm > s.hpm then excluded.hits  else s.hits  end,
    shots       = case when excluded.hpm > s.hpm then excluded.shots else s.shots end,
    best_score  = greatest(s.best_score, excluded.best_score),
    games       = s.games + 1,
    total_hits  = s.total_hits + excluded.total_hits,
    total_shots = s.total_shots + excluded.total_shots,
    total_secs  = s.total_secs + excluded.total_secs,
    updated_at  = now()
  returning * into r;

  return r;
end;
$$;

revoke all on function public.submit_result(uuid, text, text, integer, integer, integer, integer) from public;
grant execute on function public.submit_result(uuid, text, text, integer, integer, integer, integer) to anon, authenticated;

-- Optional: Bestenliste zurücksetzen
--   truncate public.scores, public.players;
-- Optional: einen Eintrag entfernen (z. B. unpassender Name)
--   delete from public.players where player_id = (select player_id from public.scores where name = '...');
