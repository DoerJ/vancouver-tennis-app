create or replace function public.update_event_max_players(
    event_id uuid,
    new_max_players integer
)
returns public.tennis_events
language plpgsql
security invoker
as $$
declare
    current_event public.tennis_events;
    updated_event public.tennis_events;
    current_player_count integer;
    new_limit_text text;
begin
    if auth.uid() is null then
        raise exception 'User must be authenticated.';
    end if;

    select *
    into current_event
    from public.tennis_events
    where id = event_id
      and host_id = auth.uid()
    for update;

    if not found then
        raise exception 'Only the event host can edit the maximum players.';
    end if;

    current_player_count := 1 + cardinality(coalesce(current_event.participants, '{}'::uuid[]));

    if new_max_players is not null and new_max_players < current_player_count then
        raise exception 'Maximum players cannot be less than the current player count of %.', current_player_count;
    end if;

    if new_max_players is not null and new_max_players <= 0 then
        raise exception 'Maximum players must be at least 1.';
    end if;

    if current_event.max_players is not distinct from new_max_players then
        return current_event;
    end if;

    update public.tennis_events
    set
        max_players = new_max_players,
        updated_at = now()
    where id = event_id
    returning * into updated_event;

    if cardinality(coalesce(current_event.participants, '{}'::uuid[])) > 0 then
        new_limit_text := coalesce(new_max_players::text, 'Unlimited');

        insert into public.notifications (
            sender,
            recipients,
            notification_type,
            title,
            body,
            related_event_id
        )
        values (
            auth.uid(),
            current_event.participants,
            'event_updated',
            'Event capacity changed',
            'The maximum players for an event you joined has changed to ' || new_limit_text || '.',
            event_id
        );
    end if;

    return updated_event;
end;
$$;

grant execute on function public.update_event_max_players(uuid, integer) to authenticated;

notify pgrst, 'reload schema';
