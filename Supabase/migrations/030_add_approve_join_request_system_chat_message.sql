create or replace function public.approve_join_request(
    notification_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    current_user_id uuid := auth.uid();
    event_id uuid;
    participant_id uuid;
    participant_display_name text;
    event_max_players integer;
    event_participants uuid[];
    is_existing_participant boolean;
begin
    if current_user_id is null then
        raise exception 'Not authenticated';
    end if;

    select related_event_id, sender
    into event_id, participant_id
    from public.notifications
    where id = notification_id
      and notification_type = 'event_joined'
      and current_user_id = any(recipients);

    if event_id is null or participant_id is null then
        raise exception 'Join request notification was not found.';
    end if;

    select max_players, participants
    into event_max_players, event_participants
    from public.tennis_events
    where id = event_id
      and host_id = current_user_id
    for update;

    if not found then
        raise exception 'Only the event host can approve this request.';
    end if;

    is_existing_participant := participant_id = any(coalesce(event_participants, '{}'::uuid[]));

    if not is_existing_participant
       and event_max_players is not null
       and 1 + cardinality(coalesce(event_participants, '{}'::uuid[])) >= event_max_players then
        raise exception 'This event is already full.';
    end if;

    update public.tennis_events
    set
        participants = case
            when is_existing_participant
                then participants
            else array_append(coalesce(participants, '{}'::uuid[]), participant_id)
        end,
        updated_at = now()
    where id = event_id;

    update public.profiles
    set
        participated_events = case
            when event_id = any(coalesce(participated_events, '{}'::uuid[]))
                then participated_events
            else array_append(coalesce(participated_events, '{}'::uuid[]), event_id)
        end,
        updated_at = now()
    where id = participant_id;

    if not is_existing_participant then
        select coalesce(nullif(trim(display_name), ''), 'A participant')
        into participant_display_name
        from public.profiles
        where id = participant_id;

        insert into public.chat_messages (
            event_id,
            sender_id,
            body
        )
        values (
            event_id,
            participant_id,
            '__van_tennis_system__ ' || coalesce(participant_display_name, 'A participant') || ' has joined the room.'
        );
    end if;
end;
$$;

grant execute on function public.approve_join_request(uuid) to authenticated;

notify pgrst, 'reload schema';
