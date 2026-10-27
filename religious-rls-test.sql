begin;
insert into auth.users(id,email) values('00000000-0000-4000-8000-000000002001','religious-owner@example.invalid'),('00000000-0000-4000-8000-000000002002','religious-outsider@example.invalid');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000002001',true);
insert into public.pp_religious_requests(owner_id,name,area,website,representative,contact_email,evidence) values('00000000-0000-4000-8000-000000002001','Test Religious Organization','Fresno','https://example.invalid','Test Representative','test@example.invalid','Test directory');
reset role;
update public.pp_religious_requests set id='00000000-0000-4000-8000-000000002003' where owner_id='00000000-0000-4000-8000-000000002001';
set local role authenticated;
do $$ begin
 begin perform public.pp_review_religious_request('00000000-0000-4000-8000-000000002003',true,'Self approval');raise exception 'TEST: self-approval allowed';exception when insufficient_privilege then null;end;
 begin insert into public.pp_religious_requests(owner_id,name,area,website,representative,contact_email,evidence,status) values('00000000-0000-4000-8000-000000002001','Test','Fresno','https://example.invalid','Rep','test@example.invalid','Evidence','approved');raise exception 'TEST: spoofed status allowed';exception when insufficient_privilege then null;end;
 begin insert into public.pp_religious_orgs(request_id,owner_id,name,area,website) values('00000000-0000-4000-8000-000000002003','00000000-0000-4000-8000-000000002001','Spoofed','Fresno','https://example.invalid');raise exception 'TEST: self-verification allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
select public.pp_review_religious_request('00000000-0000-4000-8000-000000002003',true,'Test authorized review; rollback only');
set local role authenticated;
do $$ declare org uuid;begin
 select id into strict org from public.pp_religious_orgs where request_id='00000000-0000-4000-8000-000000002003';
 insert into public.pp_religious_posts(org_id,kind,title,body,language) values(org,'ad','Community gathering','Welcome to our gathering.','en-US'),(org,'prayer','Call to Prayer','A written prayer for listening.','en-US');
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000002002',true);
do $$ declare org uuid;n int;begin
 select count(*) into n from public.pp_religious_requests where id='00000000-0000-4000-8000-000000002003';if n<>0 then raise exception 'TEST: private request leaked';end if;
 select id into strict org from public.pp_religious_orgs where request_id='00000000-0000-4000-8000-000000002003';
 begin insert into public.pp_religious_posts(org_id,kind,title,body) values(org,'ad','Forged','Unauthorized');raise exception 'TEST: cross-owner posting allowed';exception when insufficient_privilege then null;end;
 delete from public.pp_religious_posts where org_id=org;get diagnostics n=row_count;if n<>0 then raise exception 'TEST: cross-owner deletion allowed';end if;
end $$;
reset role;
update public.pp_religious_orgs set verified=false where request_id='00000000-0000-4000-8000-000000002003';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000002001',true);
do $$ declare org uuid;begin
 select id into strict org from public.pp_religious_orgs where request_id='00000000-0000-4000-8000-000000002003';
 begin insert into public.pp_religious_posts(org_id,kind,title,body) values(org,'prayer','Revoked','Hidden');raise exception 'TEST: unverified posting allowed';exception when insufficient_privilege then null;end;
end $$;
set local role anon;
select set_config('request.jwt.claim.sub','',true);
do $$ declare n int;begin select count(*) into n from public.pp_religious_posts p join public.pp_religious_orgs o on o.id=p.org_id where o.request_id='00000000-0000-4000-8000-000000002003';if n<>0 then raise exception 'TEST: revoked content public';end if;end $$;
rollback;
select 'PASS: manual approval required; self-verification/status spoofing denied; approved owner can publish ads and prayers; private requests protected; cross-owner posting/deletion denied; revocation hides posts and blocks publication. All fixtures rolled back.' as result;
