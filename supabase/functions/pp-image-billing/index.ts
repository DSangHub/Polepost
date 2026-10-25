import Stripe from 'npm:stripe@22.6.0';
import {createClient} from 'npm:@supabase/supabase-js@2.57.4';
const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const key=Deno.env.get('PP_STRIPE_SECRET_KEY')||Deno.env.get('STRIPE_SECRET_KEY')||'';
const stripe=key?new Stripe(key,{apiVersion:'2026-08-26.dahlia',httpClient:Stripe.createFetchHttpClient()}):null;
const account='acct_1U4QffPG4Dmc1DVK';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'POST,GET,OPTIONS'};
const json=(v:unknown,status=200)=>new Response(JSON.stringify(v),{status,headers:{...cors,'Content-Type':'application/json','Cache-Control':'no-store'}});
const check=(r:any)=>{if(r.error)throw r.error;return r.data;};
async function ready(){if(Deno.env.get('PP_IMAGE_PAYMENTS_ENABLED')!=='true')throw Error('Paid image upgrades are not available yet.');if(!stripe)throw Error('Payment setup is unavailable.');const a=await stripe.accounts.retrieve();if(a.id!==account)throw Error('Polepost payment account needs configuration.');return stripe;}
async function fulfill(id:string,owner?:string){
 const s=await stripe!.checkout.sessions.retrieve(id,{expand:['payment_intent.latest_charge']});
 const row=check(await admin.from('pp_image_checkouts').select('user_id').eq('session_id',id).maybeSingle());
 if(!row||owner&&owner!==row.user_id||s.metadata?.user_id!==row.user_id||s.metadata?.purpose!=='pp_images_10_30d')throw Error('Invalid image checkout');
 if(s.payment_status!=='paid')return {paid:false};
 if(s.mode!=='payment'||s.amount_total!==500||s.currency!=='usd'||!s.livemode)throw Error('Payment does not match the image plan');
 const intent=s.payment_intent as Stripe.PaymentIntent;
 const charge=intent.latest_charge as Stripe.Charge;
 if(!charge||charge.refunded||charge.disputed)throw Error('Payment was refunded or disputed');
 const expires_at=check(await admin.rpc('pp_activate_image_pass',{p_session:s.id,p_intent:intent.id,p_paid_at:new Date(charge.created*1000).toISOString()}));
 return {paid:true,expires_at};
}
Deno.serve(async req=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 try{
  if(req.method==='GET'){
   try{await ready();return json({ready:true});}catch(e){console.error('pp-billing-health',e);return json({ready:false,reason:(e as Error).message});}
  }
  if(req.method!=='POST')return json({error:'POST required'},405);
  await ready();
  if(new URL(req.url).searchParams.get('webhook')==='1'){
   // The body supplies only an event ID. Retrieve the authoritative event directly
   // from Stripe over authenticated TLS; never trust submitted event fields.
   const b=await req.json();
   if(!/^evt_[A-Za-z0-9]+$/.test(b.id||''))return json({error:'Invalid event'},400);
   const event=await stripe!.events.retrieve(b.id);
   if(!event.livemode||event.account)return json({received:true});
   if(['checkout.session.completed','checkout.session.async_payment_succeeded'].includes(event.type)){
    const session=event.data.object as Stripe.Checkout.Session;
    if(session.metadata?.purpose==='pp_images_10_30d')await fulfill(session.id);
   }
   if(event.type==='charge.refunded'||event.type==='charge.dispute.created'){
    const obj=event.data.object as any;
    let pi=obj.payment_intent;
    if(event.type==='charge.dispute.created'&&!pi)pi=(await stripe!.charges.retrieve(obj.charge)).payment_intent;
    if(pi&&(event.type==='charge.dispute.created'||obj.refunded))check(await admin.from('pp_image_passes').update({revoked_at:new Date().toISOString()}).eq('payment_intent',pi));
   }
   return json({received:true});
  }
  const token=(req.headers.get('authorization')||'').replace(/^Bearer /i,'');
  const {data:{user}}=await admin.auth.getUser(token);
  if(!user)return json({error:'Sign in before purchasing.'},401);
  const b=await req.json();
  if(b.action==='confirm')return json(await fulfill(b.session_id,user.id));
  if(b.action!=='checkout')return json({error:'Unknown action'},400);
  const passes=check(await admin.from('pp_image_passes').select('session_id').eq('user_id',user.id).is('revoked_at',null).gt('expires_at',new Date().toISOString()).limit(1));
  if(passes.length)return json({error:'Your 10-image plan is already active.'},409);
  // Reuse an open checkout to avoid duplicate purchases when a customer retries.
  const recent=check(await admin.from('pp_image_checkouts').select('session_id').eq('user_id',user.id).gte('created_at',new Date(Date.now()-86400000).toISOString()).order('created_at',{ascending:false}).limit(1));
  if(recent[0]){const old=await stripe!.checkout.sessions.retrieve(recent[0].session_id);if(old.status==='open')return json({url:old.url});if(old.payment_status==='paid')return json({...await fulfill(old.id,user.id),url:'https://polepost.org/?image_payment=success&session_id='+old.id});}
  const suffix=Array.from(crypto.getRandomValues(new Uint8Array(8)),n=>String.fromCharCode(97+n%26)).join('');
  const session=await stripe!.checkout.sessions.create({mode:'payment',customer_email:user.email,
   integration_identifier:'polepost_images_'+suffix,
   line_items:[{quantity:1,price_data:{currency:'usd',unit_amount:500,product_data:{name:'Polepost — up to 10 profile images for 30 days',description:'One-time payment. Five free slots plus five extra slots. No automatic renewal.'}}}],
   metadata:{purpose:'pp_images_10_30d',user_id:user.id},client_reference_id:user.id,
   success_url:'https://polepost.org/?image_payment=success&session_id={CHECKOUT_SESSION_ID}',cancel_url:'https://polepost.org/?image_payment=cancelled'
  },{idempotencyKey:'pp-images-'+user.id+'-'+Math.floor(Date.now()/300000)});
  check(await admin.from('pp_image_checkouts').upsert({session_id:session.id,user_id:user.id},{onConflict:'session_id'}));
  return json({url:session.url});
 }catch(e){console.error('pp-image-billing',e);return json({error:'Payment request could not be completed. Please try again or contact Polepost.'},400);}
});
