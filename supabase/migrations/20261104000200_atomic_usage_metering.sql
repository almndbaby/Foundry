-- =========================================================
-- FOUNDRY: MIGRATION 0011
-- ATOMIC USAGE METERING
-- Target: Development database (London)
-- =========================================================

begin;

create or replace function private.consume_feature_usage(
  p_user_id uuid,
  p_feature_key text,
  p_quantity integer default 1,
  p_idempotency_key text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns table (
  allowed boolean,
  reason text,
  usage_count bigint,
  usage_limit integer,
  remaining bigint
)
language plpgsql
security definer
set search_path = ''
as $function$

declare
  v_feature_id uuid;
  v_reset_period public.usage_reset_period_enum;
  v_limit integer;

  v_period_start timestamptz;
  v_period_end timestamptz;

  v_usage_count bigint;

  v_existing_event uuid;

begin

  if p_user_id is null then
    raise exception 'User ID is required';
  end if;

  if p_feature_key is null
    or length(trim(p_feature_key)) = 0 then
    raise exception 'Feature key is required';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Quantity must be positive';
  end if;

  if p_metadata is null
    or jsonb_typeof(p_metadata) <> 'object' then
    raise exception 'Metadata must be a JSON object';
  end if;

  -- -------------------------------------------------------
  -- 1. FIND ACTIVE FEATURE AND ENTITLEMENT
  -- -------------------------------------------------------

  select
    f.id,
    f.reset_period,
    pf.limit_value

  into
    v_feature_id,
    v_reset_period,
    v_limit

  from public.features f

  join public.entitlements e
    on e.feature_id = f.id

  join public.plans p
    on p.id = e.plan_id

  join public.plan_features pf
    on pf.plan_id = p.id
    and pf.feature_id = f.id

  where
    f.key = p_feature_key
    and f.is_active = true
    and p.is_active = true
    and pf.is_enabled = true
    and e.user_id = p_user_id
    and e.valid_from <= now()
    and (
      e.valid_until is null
      or e.valid_until > now()
    )

  order by e.valid_from desc

  limit 1;

  if v_feature_id is null then

    return query
    select
      false,
      'feature_not_entitled'::text,
      0::bigint,
      null::integer,
      null::bigint;

    return;

  end if;

  -- -------------------------------------------------------
  -- 2. CALCULATE USAGE PERIOD
  -- -------------------------------------------------------

  case v_reset_period

    when 'daily' then

      v_period_start :=
        date_trunc('day', now() at time zone 'UTC')
        at time zone 'UTC';

      v_period_end :=
        v_period_start + interval '1 day';

    when 'monthly' then

      v_period_start :=
        date_trunc('month', now() at time zone 'UTC')
        at time zone 'UTC';

      v_period_end :=
        v_period_start + interval '1 month';

    when 'never' then

      v_period_start := '1970-01-01 00:00:00+00'::timestamptz;

      v_period_end := null;

  end case;

  -- -------------------------------------------------------
  -- 3. SERIALISE CONCURRENT REQUESTS
  -- -------------------------------------------------------

  perform pg_advisory_xact_lock(
    hashtextextended(
      p_user_id::text
      || ':'
      || v_feature_id::text
      || ':'
      || v_period_start::text,
      0
    )
  );

  -- -------------------------------------------------------
  -- 4. CHECK IDEMPOTENCY
  -- -------------------------------------------------------

  if p_idempotency_key is not null then

    select id
    into v_existing_event

    from public.usage_events

    where idempotency_key = p_idempotency_key;

    if v_existing_event is not null then

      select coalesce(uc.usage_count, 0)
      into v_usage_count

      from public.usage_counters uc

      where
        uc.user_id = p_user_id
        and uc.feature_id = v_feature_id
        and uc.period_start = v_period_start;

      return query
      select
        true,
        'duplicate_request'::text,
        coalesce(v_usage_count, 0),
        v_limit,
        case
          when v_limit is null then null::bigint
          else greatest(
            v_limit::bigint - coalesce(v_usage_count, 0),
            0
          )
        end;

      return;

    end if;

  end if;

  -- -------------------------------------------------------
  -- 5. READ CURRENT USAGE
  -- -------------------------------------------------------

  select coalesce(uc.usage_count, 0)

  into v_usage_count

  from public.usage_counters uc

  where
    uc.user_id = p_user_id
    and uc.feature_id = v_feature_id
    and uc.period_start = v_period_start;

  v_usage_count := coalesce(v_usage_count, 0);

  -- -------------------------------------------------------
  -- 6. CHECK LIMIT
  -- -------------------------------------------------------

  if v_limit is not null
    and v_usage_count + p_quantity > v_limit then

    return query
    select
      false,
      'usage_limit_reached'::text,
      v_usage_count,
      v_limit,
      greatest(v_limit::bigint - v_usage_count, 0);

    return;

  end if;

  -- -------------------------------------------------------
  -- 7. RECORD USAGE EVENT
  -- -------------------------------------------------------

  insert into public.usage_events (
    user_id,
    feature_id,
    quantity,
    idempotency_key,
    metadata
  )
  values (
    p_user_id,
    v_feature_id,
    p_quantity,
    p_idempotency_key,
    p_metadata
  );

  -- -------------------------------------------------------
  -- 8. UPDATE AGGREGATED COUNTER
  -- -------------------------------------------------------

  insert into public.usage_counters (
    user_id,
    feature_id,
    period_start,
    period_end,
    usage_count
  )
  values (
    p_user_id,
    v_feature_id,
    v_period_start,
    v_period_end,
    p_quantity
  )

  on conflict (
    user_id,
    feature_id,
    period_start
  )

  do update set
    usage_count =
      public.usage_counters.usage_count + excluded.usage_count,
    updated_at = now()

  returning usage_count
  into v_usage_count;

  -- -------------------------------------------------------
  -- 9. RETURN RESULT
  -- -------------------------------------------------------

  return query
  select
    true,
    'usage_recorded'::text,
    v_usage_count,
    v_limit,
    case
      when v_limit is null then null::bigint
      else greatest(
        v_limit::bigint - v_usage_count,
        0
      )
    end;

end;

$function$;

-- ---------------------------------------------------------
-- 10. FUNCTION PERMISSIONS
-- ---------------------------------------------------------

revoke all on function private.consume_feature_usage(
  uuid,
  text,
  integer,
  text,
  jsonb
)
from public, anon, authenticated;

grant execute on function private.consume_feature_usage(
  uuid,
  text,
  integer,
  text,
  jsonb
)
to service_role;

commit;
