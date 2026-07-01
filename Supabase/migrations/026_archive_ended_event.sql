create or replace function public.archive_ended_event(
    event_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    current_user_id uuid := auth.uid();
    target_event_id uuid := event_id;
    archived_event_id uuid;
begin
    if current_user_id is null then
        raise exception 'Not authenticated';
    end if;

    select id
    into archived_event_id
    from public.tennis_events
    where id = target_event_id
      and end_time <= now()
      and (
          host_id = current_user_id
          or current_user_id = any(coalesce(participants, '{}'::uuid[]))
      );

    if archived_event_id is null then
        raise exception 'Ended event was not found.';
    end if;

    update public.profiles
    set
        hosted_events = array_remove(coalesce(hosted_events, '{}'::uuid[]), archived_event_id),
        participated_events = array_remove(coalesce(participated_events, '{}'::uuid[]), archived_event_id),
        updated_at = now()
    where archived_event_id = any(coalesce(hosted_events, '{}'::uuid[]))
       or archived_event_id = any(coalesce(participated_events, '{}'::uuid[]));

    delete from public.notifications
    where related_event_id = archived_event_id;

    delete from public.tennis_events
    where id = archived_event_id;
end;
$$;

grant execute on function public.archive_ended_event(uuid) to authenticated;

notify pgrst, 'reload schema';
