alter table public.tennis_events
add column if not exists participants uuid[] not null default '{}';

alter table public.profiles
add column if not exists participated_events uuid[] not null default '{}';

do $$
begin
    if exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'profiles'
          and column_name = 'partificated_events'
    ) then
        execute '
            update public.profiles
            set participated_events = case
                when cardinality(coalesce(participated_events, ''{}''::uuid[])) = 0
                    then coalesce(partificated_events, ''{}''::uuid[])
                else participated_events
            end
        ';
    end if;
end $$;

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

    if not exists (
        select 1
        from public.tennis_events
        where id = event_id
          and host_id = current_user_id
    ) then
        raise exception 'Only the event host can approve this request.';
    end if;

    update public.tennis_events
    set
        participants = case
            when participant_id = any(coalesce(participants, '{}'::uuid[]))
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
end;
$$;

grant execute on function public.approve_join_request(uuid) to authenticated;

notify pgrst, 'reload schema';
