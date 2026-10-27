-- Private verification requests are separate from public organization profiles.
create table public.pp_religious_requests (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users on delete cascade,
 name text not null check(char_length(btrim(name)) between 1 and 80),
 area text not null check(char_length(btrim(area)) between 1 and 100),
 website text not null check(char_length(website) between 8 and 500 and website ~ '^https?://[^[:space:]]+$'),
 representative text not null check(char_length(btrim(representative)) between 1 and 100),
 contact_email text not null check(char_length(contact_email) between 3 and 254 and contact_email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),
 evidence text not null check(char_length(btrim(evidence)) between 1 and 1000),
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 review_note text, reviewed_at timestamptz, created_at timestamptz not null default now()
);
create unique index pp_religious_one_pending on public.pp_religious_requests(owner_id) where status='pending';
create table public.pp_religious_orgs (
 id uuid primary key default gen_random_uuid(),request_id uuid not null unique references public.pp_religious_requests,
 owner_id uuid not null references auth.users on delete cascade,
 name text not null,area text not null,website text not null,
 verified boolean not null default true, verified_at timestamptz not null default now()
);
create index pp_religious_org_owner on public.pp_religious_orgs(owner_id);
create table public.pp_religious_posts (
 id uuid primary key default gen_random_uuid(),org_id uuid not null references public.pp_religious_orgs on delete cascade,
 kind text not null check(kind in ('ad','prayer')),
 title text not null check(char_length(btrim(title)) between 1 and 80),
 body text not null check(char_length(btrim(body)) between 1 and 2000),
 language text not null default 'en-US' check(language in ('en-US','es-MX')),
 created_at timestamptz not null default now()
);
create index pp_religious_posts_org on public.pp_religious_posts(org_id,created_at desc);
alter table public.pp_religious_requests enable row level security;
alter table public.pp_religious_orgs enable row level security;
alter table public.pp_religious_posts enable row level security;
revoke all on public.pp_religious_requests,public.pp_religious_orgs,public.pp_religious_posts from anon,authenticated;
grant select on public.pp_religious_requests to authenticated;
grant insert(owner_id,name,area,website,representative,contact_email,evidence) on public.pp_religious_requests to authenticated;
grant select on public.pp_religious_orgs,public.pp_religious_posts to anon,authenticated;
grant insert(org_id,kind,title,body,language),delete on public.pp_religious_posts to authenticated;
grant all on public.pp_religious_requests,public.pp_religious_orgs,public.pp_religious_posts to service_role;
create policy "pp religious own requests" on public.pp_religious_requests for select to authenticated using((select auth.uid())=owner_id);
create policy "pp religious submit own request" on public.pp_religious_requests for insert to authenticated with check((select auth.uid())=owner_id and status='pending' and reviewed_at is null and review_note is null);
create policy "pp religious public verified organizations" on public.pp_religious_orgs for select using(verified or owner_id=(select auth.uid()));
create policy "pp religious public verified posts" on public.pp_religious_posts for select using(exists(select 1 from public.pp_religious_orgs o where o.id=org_id and o.verified));
create policy "pp religious verified owners publish" on public.pp_religious_posts for insert to authenticated with check(exists(select 1 from public.pp_religious_orgs o where o.id=org_id and o.owner_id=(select auth.uid()) and o.verified));
create policy "pp religious owners remove posts" on public.pp_religious_posts for delete to authenticated using(exists(select 1 from public.pp_religious_orgs o where o.id=org_id and o.owner_id=(select auth.uid())));

-- Administrative approval only. API users cannot grant themselves verification.
create function public.pp_review_religious_request(p_request uuid,p_approve boolean,p_note text)
returns uuid language plpgsql security invoker set search_path='' as $$
declare r public.pp_religious_requests; org uuid;
begin
 select * into strict r from public.pp_religious_requests where id=p_request for update;
 if r.status<>'pending' then raise exception 'Request has already been reviewed'; end if;
 if nullif(btrim(p_note),'') is null then raise exception 'Review note is required'; end if;
 if p_approve then
  insert into public.pp_religious_orgs(request_id,owner_id,name,area,website) values(r.id,r.owner_id,r.name,r.area,r.website) returning id into org;
 end if;
 update public.pp_religious_requests set status=case when p_approve then 'approved' else 'rejected' end,review_note=left(p_note,2000),reviewed_at=now() where id=r.id;
 return org;
end $$;
revoke all on function public.pp_review_religious_request(uuid,boolean,text) from public,anon,authenticated;
grant execute on function public.pp_review_religious_request(uuid,boolean,text) to service_role;
