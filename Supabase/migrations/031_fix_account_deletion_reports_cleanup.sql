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
        cancellation_recipients.recipients,
        'event_cancelled',
        'Event cancelled',
        'The host cancelled an event at ' || event.location_court || '.',
        event.id
    from public.tennis_events event
    cross join lateral (
        select coalesce(array_agg(distinct recipient.user_id), '{}'::uuid[]) as recipients
        from unnest(
            coalesce(event.participants, '{}'::uuid[])
            || coalesce(
                (
                    select array_agg(distinct notification.sender)
                    from public.notifications notification
                    where notification.related_event_id = event.id
                      and notification.notification_type = 'event_joined'
                      and notification.sender is not null
                ),
                '{}'::uuid[]
            )
        ) as recipient(user_id)
        where recipient.user_id <> current_user_id
    ) cancellation_recipients
    where event.id = any(hosted_event_ids)
      and cardinality(coalesce(cancellation_recipients.recipients, '{}'::uuid[])) > 0;

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

    delete from public.reports
    where reported_event_id = any(hosted_event_ids);

    delete from public.tennis_events
    where id = any(hosted_event_ids);
end;
$$;

grant execute on function public.cancel_hosted_events_for_account_deletion() to authenticated;

create or replace function public.delete_account_profile_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    current_user_id uuid := auth.uid();
    participated_event_ids uuid[];
    profile_display_name text;
begin
    if current_user_id is null then
        raise exception 'Not authenticated';
    end if;

    delete from public.reports
    where reporter_id = current_user_id
       or reported_user_id = current_user_id;

    perform public.cancel_hosted_events_for_account_deletion();

    select display_name
    into profile_display_name
    from public.profiles
    where id = current_user_id;

    select coalesce(array_agg(id), '{}'::uuid[])
    into participated_event_ids
    from public.tennis_events
    where host_id <> current_user_id
      and current_user_id = any(coalesce(participants, '{}'::uuid[]));

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
        array[host_id],
        'event_left',
        'Player left your event',
        coalesce(profile_display_name, 'A player') || ' left your event at ' || location_court || '.',
        id
    from public.tennis_events
    where id = any(participated_event_ids)
      and host_id is not null;

    update public.tennis_events
    set
        participants = array_remove(coalesce(participants, '{}'::uuid[]), current_user_id),
        updated_at = now()
    where id = any(participated_event_ids);

    delete from public.notifications
    where current_user_id = any(coalesce(recipients, '{}'::uuid[]))
      and cardinality(coalesce(recipients, '{}'::uuid[])) <= 1;

    update public.notifications
    set
        recipients = array_remove(coalesce(recipients, '{}'::uuid[]), current_user_id),
        read_by = array_remove(coalesce(read_by, '{}'::uuid[]), current_user_id),
        updated_at = now()
    where current_user_id = any(coalesce(recipients, '{}'::uuid[]))
      and cardinality(coalesce(recipients, '{}'::uuid[])) > 1;

    update public.notifications
    set
        read_by = array_remove(coalesce(read_by, '{}'::uuid[]), current_user_id),
        updated_at = now()
    where current_user_id = any(coalesce(read_by, '{}'::uuid[]));

    delete from public.device_tokens
    where user_id = current_user_id;

    delete from public.profiles
    where id = current_user_id;
end;
$$;

grant execute on function public.delete_account_profile_data() to authenticated;

notify pgrst, 'reload schema';
