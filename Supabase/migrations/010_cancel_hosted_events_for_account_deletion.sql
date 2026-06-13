create or replace function public.cancel_hosted_events_for_account_deletion()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    current_user_id uuid := auth.uid();
    hosted_event_ids uuid[];
begin
    if current_user_id is null then
        raise exception 'Not authenticated';
    end if;

    select coalesce(array_agg(id), '{}'::uuid[])
    into hosted_event_ids
    from public.tennis_events
    where host_id = current_user_id;

    if cardinality(hosted_event_ids) = 0 then
        update public.profiles
        set
            hosted_events = '{}'::uuid[],
            updated_at = now()
        where id = current_user_id
          and cardinality(coalesce(hosted_events, '{}'::uuid[])) > 0;

        return;
    end if;

    insert into public.notifications (
        sender,
        recipients,
        notification_type,
        title,
        body,
        related_event_id
    )
    select
        current_user_id,
        participants,
        'event_cancelled',
        'Event cancelled',
        'The host cancelled an event at ' || location_court || '.',
        id
    from public.tennis_events
    where id = any(hosted_event_ids)
      and cardinality(coalesce(participants, '{}'::uuid[])) > 0;

    update public.profiles
    set
        participated_events = coalesce(
            (
                select array_agg(event_id)
                from unnest(coalesce(participated_events, '{}'::uuid[])) as event_id
                where event_id <> all(hosted_event_ids)
            ),
            '{}'::uuid[]
        ),
        updated_at = now()
    where participated_events && hosted_event_ids;

    update public.profiles
    set
        hosted_events = coalesce(
            (
                select array_agg(event_id)
                from unnest(coalesce(hosted_events, '{}'::uuid[])) as event_id
                where event_id <> all(hosted_event_ids)
            ),
            '{}'::uuid[]
        ),
        updated_at = now()
    where id = current_user_id;

    delete from public.tennis_events
    where id = any(hosted_event_ids);
end;
$$;

grant execute on function public.cancel_hosted_events_for_account_deletion() to authenticated;

notify pgrst, 'reload schema';
