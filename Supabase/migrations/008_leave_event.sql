create or replace function public.leave_event(
    event_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    current_user_id uuid := auth.uid();
begin
    if current_user_id is null then
        raise exception 'Not authenticated';
    end if;

    if not exists (
        select 1
        from public.tennis_events
        where id = event_id
    ) then
        raise exception 'Event was not found.';
    end if;

    if not exists (
        select 1
        from public.tennis_events
        where id = event_id
          and current_user_id = any(coalesce(participants, '{}'::uuid[]))
    ) then
        raise exception 'User is not a participant of this event.';
    end if;

    update public.tennis_events
    set
        participants = array_remove(coalesce(participants, '{}'::uuid[]), current_user_id),
        updated_at = now()
    where id = event_id;

    update public.profiles
    set
        participated_events = array_remove(coalesce(participated_events, '{}'::uuid[]), event_id),
        updated_at = now()
    where id = current_user_id;
end;
$$;

grant execute on function public.leave_event(uuid) to authenticated;

notify pgrst, 'reload schema';
