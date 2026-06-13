create or replace function public.cancel_hosted_event(
    event_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    current_user_id uuid := auth.uid();
    event_participants uuid[];
    event_court text;
begin
    if current_user_id is null then
        raise exception 'Not authenticated';
    end if;

    select participants, location_court
    into event_participants, event_court
    from public.tennis_events
    where id = event_id
      and host_id = current_user_id;

    if event_participants is null then
        raise exception 'Hosted event was not found.';
    end if;

    if cardinality(coalesce(event_participants, '{}'::uuid[])) > 0 then
        insert into public.notifications (
            sender,
            recipients,
            notification_type,
            title,
            body,
            related_event_id
        )
        values (
            current_user_id,
            event_participants,
            'event_cancelled',
            'Event cancelled',
            'The host cancelled an event at ' || event_court || '.',
            event_id
        );
    end if;

    update public.profiles
    set
        participated_events = array_remove(coalesce(participated_events, '{}'::uuid[]), event_id),
        updated_at = now()
    where event_id = any(coalesce(participated_events, '{}'::uuid[]));

    update public.profiles
    set
        hosted_events = array_remove(coalesce(hosted_events, '{}'::uuid[]), event_id),
        updated_at = now()
    where id = current_user_id;

    delete from public.tennis_events
    where id = event_id
      and host_id = current_user_id;
end;
$$;

grant execute on function public.cancel_hosted_event(uuid) to authenticated;

notify pgrst, 'reload schema';
