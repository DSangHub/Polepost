create table public.pp_forum_profiles (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users on delete cascade,
 name text not null check(char_length(btrim(name)) between 1 and 80),
 category text not null check(category in ('music_groups','bands','local_businesses','religious_organizations')),
 area text not null check(char_length(btrim(area)) between 1 and 100),
 bio text not null check(char_length(btrim(bio)) between 1 and 500),
 created_at timestamptz not null default now()
);
create index pp_forum_profiles_category on public.pp_forum_profiles(category,created_at desc);
create index pp_forum_profiles_owner on public.pp_forum_profiles(owner_id);
create table public.pp_forum_feedback (
 id uuid primary key default gen_random_uuid(),
 profile_id uuid not null references public.pp_forum_profiles on delete cascade,
 author_id uuid not null references auth.users on delete cascade,
 display_name text not null check(char_length(btrim(display_name)) between 1 and 64),
 body text not null check(char_length(btrim(body)) between 1 and 1000),
 created_at timestamptz not null default now()
);
create index pp_forum_feedback_profile on public.pp_forum_feedback(profile_id,created_at desc);
create index pp_forum_feedback_author on public.pp_forum_feedback(author_id);
alter table public.pp_forum_profiles enable row level security;
alter table public.pp_forum_feedback enable row level security;
revoke all on public.pp_forum_profiles,public.pp_forum_feedback from anon,authenticated;
grant select on public.pp_forum_profiles,public.pp_forum_feedback to anon,authenticated;
grant insert,update on public.pp_forum_profiles to authenticated;
grant insert,delete on public.pp_forum_feedback to authenticated;
grant all on public.pp_forum_profiles,public.pp_forum_feedback to service_role;
create policy "pp forum profiles public" on public.pp_forum_profiles for select using(true);
create policy "pp forum create own profile" on public.pp_forum_profiles for insert to authenticated with check((select auth.uid())=owner_id);
create policy "pp forum edit own profile" on public.pp_forum_profiles for update to authenticated using((select auth.uid())=owner_id) with check((select auth.uid())=owner_id);
create policy "pp forum feedback public" on public.pp_forum_feedback for select using(true);
create policy "pp forum feedback as yourself" on public.pp_forum_feedback for insert to authenticated with check((select auth.uid())=author_id);
create policy "pp forum remove own feedback" on public.pp_forum_feedback for delete to authenticated using((select auth.uid())=author_id);
