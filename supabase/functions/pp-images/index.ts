import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
const admin = createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const bucket='pp-profile-images';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'POST,OPTIONS'};
const json=(v:unknown,status=200)=>new Response(JSON.stringify(v),{status,headers:{...cors,'Content-Type':'application/json','Cache-Control':'no-store'}});
const check=(r:any)=>{if(r.error)throw r.error;return r.data;};
async function entitlement(id:string){
 const rows=check(await admin.from('pp_image_passes').select('expires_at').eq('user_id',id).is('revoked_at',null).gt('expires_at',new Date().toISOString()).order('expires_at',{ascending:false}).limit(1));
 return rows[0]?.expires_at||null;
}
Deno.serve(async req=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(req.method!=='POST')return json({error:'POST required'},405);
 try{
  if(Number(req.headers.get('content-length'))>5300000)return json({error:'Images must be 5 MB or smaller.'},413);
  const token=(req.headers.get('authorization')||'').replace(/^Bearer /i,'');
  const {data:{user}}=await admin.auth.getUser(token);
  const form=req.headers.get('content-type')?.includes('multipart/form-data')?await req.formData():null;
  const body=form?{action:'upload'}:await req.json();
  if(body.action==='gallery'){
   const id=String(body.user_id||'');
   if(!/^[0-9a-f-]{36}$/i.test(id))return json({error:'Invalid profile'},400);
   const until=await entitlement(id),owner=user?.id===id;
   const rows=check(await admin.from('pp_profile_images').select('id,slot,object_path,state').eq('user_id',id).order('slot'));
   const images=[];
   for(const row of rows){
    const active=row.state==='ready'&&(row.slot<=5||!!until);
    if(!owner&&!active)continue;
    let url=null;
    if(row.state==='ready'){
     const lifetime=owner||row.slot<=5?60:Math.max(1,Math.min(60,Math.floor((Date.parse(until)-Date.now())/1000)));
     url=check(await admin.storage.from(bucket).createSignedUrl(row.object_path,lifetime)).signedUrl;
    }
    images.push({id:row.id,slot:row.slot,active,url});
   }
   return json({images,limit:until?10:5,expires_at:until});
  }
  if(!user)return json({error:'Sign in to manage your images.'},401);
  if(body.action==='upload'){
   const file=form?.get('image');
   if(!(file instanceof File)||file.size>5242880||file.size===0)return json({error:'Choose an image up to 5 MB.'},400);
   const bytes=new Uint8Array(await file.arrayBuffer());
   let ext='',type='';
   if(bytes[0]===255&&bytes[1]===216&&bytes[2]===255){ext='jpg';type='image/jpeg';}
   else if([137,80,78,71,13,10,26,10].every((n,i)=>bytes[i]===n)){ext='png';type='image/png';}
   else if(new TextDecoder().decode(bytes.slice(0,4))==='RIFF'&&new TextDecoder().decode(bytes.slice(8,12))==='WEBP'){ext='webp';type='image/webp';}
   else return json({error:'Use a JPG, PNG, or WebP image.'},400);
   const row=check(await admin.rpc('pp_reserve_image',{p_user:user.id,p_ext:ext}));
   try{
    check(await admin.storage.from(bucket).upload(row.object_path,bytes,{contentType:type,upsert:false,cacheControl:'0'}));
    check(await admin.from('pp_profile_images').update({state:'ready'}).eq('id',row.id).eq('user_id',user.id));
   }catch(e){
    // Release the slot only after storage cleanup succeeds; never leave untracked files.
    const cleanup=await admin.storage.from(bucket).remove([row.object_path]);
    if(!cleanup.error)await admin.from('pp_profile_images').delete().eq('id',row.id).eq('user_id',user.id);
    throw e;
   }
   return json({ok:true,id:row.id});
  }
  if(body.action==='delete'){
   const row=check(await admin.from('pp_profile_images').select('id,object_path').eq('id',body.id).eq('user_id',user.id).maybeSingle());
   if(!row)return json({error:'Image not found'},404);
   check(await admin.storage.from(bucket).remove([row.object_path]));
   check(await admin.from('pp_profile_images').delete().eq('id',row.id).eq('user_id',user.id));
   return json({ok:true});
  }
  return json({error:'Unknown action'},400);
 }catch(e){console.error('pp-images',e);return json({error:(e as Error).message||'Image request failed'},400);}
});
