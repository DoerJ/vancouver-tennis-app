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
