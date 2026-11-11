alter table public.pp_flyers
  add column offer_days smallint[],
  add column offer_starts_at time,
  add column offer_ends_at time,
  add constraint pp_flyers_offer_days_check check (
    offer_days is null or (
      cardinality(offer_days) between 1 and 7
      and array_position(offer_days, null) is null
      and offer_days <@ array[1,2,3,4,5,6,7]::smallint[]
    )
  ),
  add constraint pp_flyers_offer_hours_check check (
    (offer_starts_at is null and offer_ends_at is null)
    or (offer_starts_at is not null and offer_ends_at is not null and offer_starts_at < offer_ends_at)
  );
