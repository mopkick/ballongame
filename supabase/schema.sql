-- Ballonalarm: Bestenliste für den Online-Modus
-- Einmal im Supabase-Dashboard unter "SQL Editor" ausführen.
--
-- Wie es funktioniert:
-- * Jede Spielerin / jeder Spieler bekommt beim ersten Start automatisch ein
--   anonymes Konto (Supabase "Anonymous Sign-Ins"), ganz ohne E-Mail.
-- * Pro Konto gibt es genau eine Zeile mit der besten Runde und Summen.
-- * Lesen darf jeder, schreiben nur über die Funktion submit_result(),
--   die Treffer/min selbst ausrechnet und unsinnige Werte ablehnt.

create table if not exists public.scores (
  player_id   uuid primary key references auth.users (id) on delete cascade,
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
  for select using (true);
-- Absichtlich keine insert/update/delete-Policies: geschrieben wird nur über submit_result().

create or replace function public.submit_result(
  p_name text, p_hits integer, p_shots integer, p_secs integer, p_score integer
) returns public.scores
language plpgsql
security definer
set search_path = public
as $$
declare
  uid   uuid := auth.uid();
  v_name text := left(btrim(coalesce(p_name, '')), 20);
  v_hpm numeric;
  v_spm numeric;
  v_acc integer;
  r     public.scores;
begin
  if uid is null then
    raise exception 'not signed in';
  end if;
  -- Plausibilitätsprüfung: Runde 20 s bis 10 min, max. 8 Schüsse pro Sekunde,
  -- nie mehr Treffer als Schüsse (+ Doppeltreffer-Spielraum).
  if p_secs < 20 or p_secs > 600
     or p_shots < 0 or p_shots > p_secs * 8
     or p_hits < 0 or p_hits > p_shots * 2
     or p_score < 0 or p_score > 100000 then
    raise exception 'invalid result';
  end if;
  if v_name = '' then v_name := 'Anonym'; end if;

  v_hpm := round(p_hits / (p_secs / 60.0), 1);
  v_spm := round(p_shots / (p_secs / 60.0), 1);
  v_acc := case when p_shots > 0 then round(100.0 * least(p_hits, p_shots) / p_shots) else 0 end;

  insert into public.scores as s
    (player_id, name, hpm, spm, acc, hits, shots, best_score, games, total_hits, total_shots, total_secs, updated_at)
  values
    (uid, v_name, v_hpm, v_spm, v_acc, p_hits, p_shots, p_score, 1, p_hits, p_shots, p_secs, now())
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

revoke all on function public.submit_result(text, integer, integer, integer, integer) from public, anon;
grant execute on function public.submit_result(text, integer, integer, integer, integer) to authenticated;

-- Optional: Bestenliste zurücksetzen
--   truncate public.scores;
-- Optional: einen Eintrag entfernen (z. B. unpassender Name)
--   delete from public.scores where name = '...';
