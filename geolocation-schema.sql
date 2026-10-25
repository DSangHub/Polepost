-- Existing posts remain unlocated until their author adds a location.
alter table public.pp_flyers
 add column latitude double precision,
 add column longitude double precision,
 add column location_accuracy_meters double precision,
 add constraint pp_flyer_coordinates check (
  (latitude is null and longitude is null and location_accuracy_meters is null)
  or (latitude is not null and longitude is not null
   and latitude between -90 and 90 and longitude between -180 and 180
   and (location_accuracy_meters is null or location_accuracy_meters between 0 and 100000))
 );
