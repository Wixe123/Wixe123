-- binclean: databas för bokningar och ekonomi.
-- Kör hela filen en gång i Supabase → SQL Editor → New query → Run.

create extension if not exists pgcrypto;

-- Vilka konton som är administratörer (du).
create table if not exists public.admins (
  user_id uuid primary key references auth.users on delete cascade
);
alter table public.admins enable row level security; -- inga policys: bara databasen själv läser den

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid())
$$;

-- Bokningar från kunder.
create table if not exists public.bokningar (
  id uuid primary key default gen_random_uuid(),
  datum date not null,
  antal int not null check (antal between 1 and 4),
  typ text not null default 'en' check (typ in ('en', 'abo')),
  summa int not null default 0,
  namn text not null check (char_length(namn) between 1 and 200),
  adress text not null check (char_length(adress) between 1 and 200),
  postnr text not null check (postnr ~ '^[0-9]{3} ?[0-9]{2}$'),
  ort text not null check (char_length(ort) between 1 and 100),
  telefon text not null check (char_length(telefon) between 1 and 40),
  epost text not null check (char_length(epost) between 3 and 200),
  ovrigt text check (char_length(ovrigt) <= 1000),
  status text not null default 'bokad' check (status in ('bokad', 'utford', 'avbokad')),
  skapad timestamptz not null default now()
);

-- Priset räknas ut i databasen så att ingen kan ändra det i webbläsaren.
-- 125 kr per tunna, 240 kr för två, abonnemang −15 %.
create or replace function public.bokning_fore_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    new.status := 'bokad';
    new.skapad := now();
    if new.datum < current_date - 1 or new.datum > current_date + 90 then
      raise exception 'Ogiltigt datum';
    end if;
  end if;
  new.summa := (new.antal / 2) * 240 + (new.antal % 2) * 125;
  if new.typ = 'abo' then
    new.summa := round(new.summa * 0.85);
  end if;
  return new;
end $$;

drop trigger if exists bokning_fore_insert on public.bokningar;
create trigger bokning_fore_insert before insert on public.bokningar
  for each row execute function public.bokning_fore_insert();

alter table public.bokningar enable row level security;
drop policy if exists "alla kan boka" on public.bokningar;
create policy "alla kan boka" on public.bokningar for insert to anon, authenticated with check (true);
drop policy if exists "admin läser" on public.bokningar;
create policy "admin läser" on public.bokningar for select to authenticated using (public.is_admin());
drop policy if exists "admin ändrar" on public.bokningar;
create policy "admin ändrar" on public.bokningar for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "admin tar bort" on public.bokningar;
create policy "admin tar bort" on public.bokningar for delete to authenticated using (public.is_admin());

-- Egna intäkter och utgifter.
create table if not exists public.ekonomi (
  id uuid primary key default gen_random_uuid(),
  datum date not null,
  typ text not null check (typ in ('intakt', 'utgift')),
  text text check (char_length(text) <= 300),
  belopp numeric(12, 2) not null check (belopp > 0),
  skapad timestamptz not null default now()
);
alter table public.ekonomi enable row level security;
drop policy if exists "bara admin" on public.ekonomi;
create policy "bara admin" on public.ekonomi for all to authenticated using (public.is_admin()) with check (public.is_admin());
