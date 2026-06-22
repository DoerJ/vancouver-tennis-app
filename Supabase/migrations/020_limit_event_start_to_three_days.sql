create or replace function public.create_tennis_event(
    p_start_time timestamptz,
    p_end_time timestamptz,
    p_event_type text,
    p_max_players integer,
    p_location_city text,
    p_location_court text,
    p_skill_level text
)
returns public.tennis_events
language plpgsql
security invoker
as $$
declare
    created_event public.tennis_events;
begin
    if auth.uid() is null then
        raise exception 'User must be authenticated to create an event.';
    end if;

    if p_start_time <= now() then
        raise exception 'Start time must be in the future.';
    end if;

    if p_start_time > now() + interval '3 days' then
        raise exception 'Start time must be within the next 3 days.';
    end if;

    if p_end_time <= p_start_time then
        raise exception 'End time must be after start time.';
    end if;

    if p_max_players is not null and p_max_players <= 0 then
        raise exception 'Max players must be at least 1.';
    end if;

    if (
        select count(*)
        from public.tennis_events
        where host_id = auth.uid()
          and end_time > now()
    ) >= 3 then
        raise exception 'You can host up to 3 events at a time.';
    end if;

    if exists (
        select 1
        from public.tennis_events
        where host_id = auth.uid()
          and end_time > now()
          and p_start_time < end_time
          and p_end_time > start_time
    ) then
        raise exception 'This event overlaps with one of your hosted events.';
    end if;

    insert into public.tennis_events (
        host_id,
        start_time,
        end_time,
        event_type,
        max_players,
        location_city,
        location_court,
        skill_level,
        participants
    )
    values (
        auth.uid(),
        p_start_time,
        p_end_time,
        p_event_type,
        p_max_players,
        p_location_city,
        p_location_court,
        p_skill_level,
        '{}'
    )
    returning * into created_event;

    return created_event;
end;
$$;

grant execute on function public.create_tennis_event(
    timestamptz,
    timestamptz,
    text,
    integer,
    text,
    text,
    text
) to authenticated;

notify pgrst, 'reload schema';
