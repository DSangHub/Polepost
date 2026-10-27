-- Site-published community notices; no organization verification is implied.
create table public.pp_community_ads (
 id uuid primary key default gen_random_uuid(),
 campaign_key text not null unique,
 zip_code text not null check(zip_code ~ '^[0-9]{5}$'),
 title text not null check(char_length(title) between 1 and 100),
 body text not null check(char_length(body) between 1 and 1000),
 image_path text not null check(image_path ~ '^/assets/[A-Za-z0-9._-]+$'),
 created_at timestamptz not null default now(),
 expires_at timestamptz not null default now()+interval '30 days'
);
alter table public.pp_community_ads enable row level security;
revoke all on public.pp_community_ads from anon,authenticated;
grant select on public.pp_community_ads to anon,authenticated;
grant all on public.pp_community_ads to service_role;
create policy "pp public current community ads" on public.pp_community_ads for select using(expires_at>now());
create index pp_community_ads_zip on public.pp_community_ads(zip_code,expires_at);
