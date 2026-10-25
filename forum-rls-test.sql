begin;
insert into auth.users(id,email) values ('00000000-0000-4000-8000-000000001001','forum-owner@example.invalid'),('00000000-0000-4000-8000-000000001002','forum-member@example.invalid');
insert into public.pp_forum_profiles(id,owner_id,name,category,area,bio) values ('00000000-0000-4000-8000-000000001003','00000000-0000-4000-8000-000000001001','Test Band','bands','Fresno','Local music.');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001002',true);
do $$ declare n int; begin
update public.pp_forum_profiles set bio='Unauthorized' where id='00000000-0000-4000-8000-000000001003';
get diagnostics n=row_count; if n<>0 then raise exception 'Cross-owner update allowed'; end if;
begin insert into public.pp_forum_profiles(owner_id,name,category,area,bio) values('00000000-0000-4000-8000-000000001001','Forged','bands','Fresno','No'); raise exception 'TEST impersonation allowed'; exception when insufficient_privilege then null; end;
insert into public.pp_forum_feedback(id,profile_id,author_id,display_name,body) values ('00000000-0000-4000-8000-000000001004','00000000-0000-4000-8000-000000001003','00000000-0000-4000-8000-000000001002','Community member','Great local show.');
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001001',true);
do $$ declare n int; begin
update public.pp_forum_profiles set bio='Updated by owner' where id='00000000-0000-4000-8000-000000001003';
get diagnostics n=row_count; if n<>1 then raise exception 'Owner update failed'; end if;
delete from public.pp_forum_feedback where id='00000000-0000-4000-8000-000000001004';
get diagnostics n=row_count; if n<>0 then raise exception 'Organization deleted another author feedback'; end if;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000001002',true);
do $$ declare n int; begin delete from public.pp_forum_feedback where id='00000000-0000-4000-8000-000000001004'; get diagnostics n=row_count; if n<>1 then raise exception 'Author deletion failed'; end if; end $$;
set local role anon;
do $$ declare n int; begin select count(*) into n from public.pp_forum_profiles where id='00000000-0000-4000-8000-000000001003'; if n<>1 then raise exception 'Public read failed'; end if; end $$;
rollback;
select 'PASS: public browsing, signed-in feedback, owner editing, blocked impersonation, blocked cross-owner edits and feedback deletion; fixtures rolled back' as result;
