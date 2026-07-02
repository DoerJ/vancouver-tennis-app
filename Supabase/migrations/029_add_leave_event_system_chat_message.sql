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
    participant_display_name text;
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

    select coalesce(nullif(trim(display_name), ''), 'A participant')
    into participant_display_name
    from public.profiles
    where id = current_user_id;

    insert into public.chat_messages (
        event_id,
        sender_id,
        body
    )
    values (
        event_id,
        current_user_id,
        '__van_tennis_system__ ' || coalesce(participant_display_name, 'A participant') || ' has left the room.'
    );

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
