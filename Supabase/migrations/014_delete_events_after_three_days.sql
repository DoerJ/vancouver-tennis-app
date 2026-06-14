create or replace function public.delete_expired_events()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    expired_event_ids uuid[];
begin
    select coalesce(array_agg(id), '{}'::uuid[])
    into expired_event_ids
    from public.tennis_events
    where end_time < now() - interval '3 days';

    if cardinality(expired_event_ids) = 0 then
        return;
    end if;

    update public.profiles
    set
        hosted_events = coalesce(
            (
                select array_agg(event_id)
                from unnest(coalesce(hosted_events, '{}'::uuid[])) as event_id
                where event_id <> all(expired_event_ids)
            ),
            '{}'::uuid[]
        ),
        participated_events = coalesce(
            (
                select array_agg(event_id)
                from unnest(coalesce(participated_events, '{}'::uuid[])) as event_id
                where event_id <> all(expired_event_ids)
            ),
            '{}'::uuid[]
        ),
        updated_at = now()
    where hosted_events && expired_event_ids
       or participated_events && expired_event_ids;

    delete from public.notifications
    where related_event_id = any(expired_event_ids);

    delete from public.tennis_events
    where id = any(expired_event_ids);
end;
$$;

grant execute on function public.delete_expired_events() to authenticated;

notify pgrst, 'reload schema';
