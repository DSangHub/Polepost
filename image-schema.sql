-- Profile image slots: five free; a verified $5 pass enables slots 6-10 for 30 days.
create table public.pp_image_checkouts (
 session_id text primary key, user_id uuid not null references auth.users on delete cascade,
 created_at timestamptz not null default now()
);
create table public.pp_image_passes (
 session_id text primary key references public.pp_image_checkouts,
 user_id uuid not null references auth.users on delete cascade,
 payment_intent text not null unique,
 starts_at timestamptz not null, expires_at timestamptz not null,
 revoked_at timestamptz
);
create index pp_image_pass_owner on public.pp_image_passes(user_id,expires_at);
create table public.pp_profile_images (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users on delete cascade,
 slot smallint not null check(slot between 1 and 10),
 object_path text not null unique,
 state text not null default 'pending' check(state in ('pending','ready')),
 created_at timestamptz not null default now(),
 unique(user_id,slot)
);
alter table public.pp_image_checkouts enable row level security;
alter table public.pp_image_passes enable row level security;
alter table public.pp_profile_images enable row level security;
revoke all on public.pp_image_checkouts,public.pp_image_passes,public.pp_profile_images from anon,authenticated;
grant all on public.pp_image_checkouts,public.pp_image_passes,public.pp_profile_images to service_role;
create policy "pp owner reads image passes" on public.pp_image_passes for select to authenticated using ((select auth.uid())=user_id);
create policy "pp owner reads images" on public.pp_profile_images for select to authenticated using ((select auth.uid())=user_id);
create policy "pp owner reads image checkouts" on public.pp_image_checkouts for select to authenticated using ((select auth.uid())=user_id);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('pp-profile-images','pp-profile-images',false,5242880,array['image/jpeg','image/png','image/webp']);
-- No client storage policies: authenticated Edge Function handles validation and quotas.

create function public.pp_reserve_image(p_user uuid,p_ext text)
returns public.pp_profile_images language plpgsql security invoker set search_path='' as $$
declare lim int := 5; chosen int; img public.pp_profile_images; new_id uuid:=gen_random_uuid();
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,817));
 if p_ext not in ('jpg','png','webp') then raise exception 'Invalid image type'; end if;
 if exists(select 1 from public.pp_image_passes where user_id=p_user and revoked_at is null and expires_at>now()) then lim:=10; end if;
 select n into chosen from generate_series(1,lim) n where not exists(select 1 from public.pp_profile_images i where i.user_id=p_user and i.slot=n) order by n limit 1;
 if chosen is null then raise exception 'Image limit reached. Five images are free; $5 enables up to 10 for 30 days.'; end if;
 insert into public.pp_profile_images(id,user_id,slot,object_path) values(new_id,p_user,chosen,p_user::text||'/'||new_id::text||'.'||p_ext) returning * into img;
 return img;
end $$;

create function public.pp_activate_image_pass(p_session text,p_intent text,p_paid_at timestamptz)
returns timestamptz language plpgsql security invoker set search_path='' as $$
declare owner_id uuid; expiry timestamptz;
begin
 select user_id into strict owner_id from public.pp_image_checkouts where session_id=p_session;
 perform pg_advisory_xact_lock(hashtextextended(owner_id::text,817));
 select expires_at into expiry from public.pp_image_passes where session_id=p_session;
 if found then return expiry; end if;
 select greatest(p_paid_at,coalesce(max(expires_at),p_paid_at))+interval '30 days' into expiry from public.pp_image_passes where user_id=owner_id and revoked_at is null;
 insert into public.pp_image_passes(session_id,user_id,payment_intent,starts_at,expires_at) values(p_session,owner_id,p_intent,p_paid_at,expiry);
 return expiry;
end $$;
revoke all on function public.pp_reserve_image(uuid,text),public.pp_activate_image_pass(text,text,timestamptz) from public,anon,authenticated;
grant execute on function public.pp_reserve_image(uuid,text),public.pp_activate_image_pass(text,text,timestamptz) to service_role;
