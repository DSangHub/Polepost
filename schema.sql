-- polepost.org — Supabase schema  (APPLIED, for reference)
--
-- Already applied to project nwwkiljmxbtzoxafsesq as migrations
-- polepost_profiles_and_flyers and polepost_lock_down_trigger_function.
--
-- Every object is prefixed pp_ because that project is shared with the
-- tt_*, cistyr_*, jobs/applications and stays/bookings apps. A bare
-- `profiles` table and a bare `on_auth_user_created` trigger already
-- belong to another app there — do not reuse those names. Auth itself needs no setup:
-- magic-link sign-in works out of the box and auth.users already stores
-- the email. These tables hold everything auth.users does not.

-- ---------------------------------------------------------------
-- profiles: the display name, home neighborhood, and default tab
-- number. One row per account, created on first sign-in.
-- ---------------------------------------------------------------
create table if not exists public.pp_profiles (
  id          uuid primary key references auth.users on delete cascade,
  name        text check (char_length(name) <= 32),
  area        text,
  phone       text check (char_length(phone) <= 24),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.pp_profiles enable row level security;

-- Names are shown on flyers, so profiles are world-readable.
create policy "pp profiles are public"
  on public.pp_profiles for select
  using (true);

create policy "pp own profile update"
  on public.pp_profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "pp own profile insert"
  on public.pp_profiles for insert
  with check (auth.uid() = id);

-- Give every new account a profile row automatically.
create or replace function public.pp_handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.pp_profiles (id) values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists pp_on_auth_user_created on auth.users;
create trigger pp_on_auth_user_created
  after insert on auth.users
  for each row execute function public.pp_handle_new_user();

-- ---------------------------------------------------------------
-- flyers: for when posts should be visible to everyone, not just
-- the browser that wrote them. The site does not read this yet.
-- ---------------------------------------------------------------
create table if not exists public.pp_flyers (
  id          uuid primary key default gen_random_uuid(),
  author      uuid not null references auth.users on delete cascade,
  title       text not null check (char_length(title) between 1 and 46),
  category    text not null check (category in
                ('gigs','instruments','eateries','handymen','services')),
  area        text not null,
  price       text,
  body        text check (char_length(body) <= 220),
  phone       text,
  created_at  timestamptz not null default now(),
  -- flyers come down after 30 days, same as the pole
  expires_at  timestamptz not null default now() + interval '30 days'
);

create index if not exists pp_flyers_live_idx
  on public.pp_flyers (category, area, created_at desc)
  where expires_at > now();

alter table public.pp_flyers enable row level security;

create policy "pp live flyers are public"
  on public.pp_flyers for select
  using (expires_at > now());

create policy "pp post as yourself"
  on public.pp_flyers for insert
  with check (auth.uid() = author);

create policy "pp edit own flyers"
  on public.pp_flyers for update
  using (auth.uid() = author)
  with check (auth.uid() = author);

create policy "pp delete own flyers"
  on public.pp_flyers for delete
  using (auth.uid() = author);

-- ---------------------------------------------------------------
-- Before going live, in Authentication -> URL Configuration:
--   Site URL:      https://polepost.org
--   Redirect URLs: https://polepost.org, http://localhost:8000
-- Without these the magic link bounces to the wrong origin.
-- ---------------------------------------------------------------

-- pp_handle_new_user is SECURITY DEFINER and would otherwise be callable
-- by anyone at /rest/v1/rpc/pp_handle_new_user. It only needs to fire
-- from the trigger, so the API roles get no execute privilege.
revoke execute on function public.pp_handle_new_user() from anon, authenticated, public;
