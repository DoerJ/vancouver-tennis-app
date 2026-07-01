create extension if not exists pg_cron;

create or replace function public.refresh_tennis_event_statuses()
returns void
language sql
security definer
set search_path = public
as $$
    update public.tennis_events
    set
        status = case
            when now() < start_time then 'upcoming'::public.tennis_event_status
            when now() >= start_time and now() < end_time then 'in_progress'::public.tennis_event_status
            else 'completed'::public.tennis_event_status
        end,
        updated_at = now()
    where status <> 'cancelled'::public.tennis_event_status
      and status is distinct from case
          when now() < start_time then 'upcoming'::public.tennis_event_status
          when now() >= start_time and now() < end_time then 'in_progress'::public.tennis_event_status
          else 'completed'::public.tennis_event_status
      end;
$$;

create or replace function public.delete_expired_events()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    expired_event_ids uuid[];
begin
    perform public.refresh_tennis_event_statuses();

    select coalesce(array_agg(id), '{}'::uuid[])
    into expired_event_ids
    from public.tennis_events
    where end_time <= now() - interval '3 days';

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

grant execute on function public.refresh_tennis_event_statuses() to authenticated;
grant execute on function public.delete_expired_events() to authenticated;

do $$
begin
    perform cron.unschedule('delete-expired-events-daily-9am-pst');
exception
    when others then
        null;
end;
$$;

select cron.schedule(
    'delete-expired-events-daily-9am-pst',
    '0 17 * * *',
    $$ select public.delete_expired_events(); $$
);

notify pgrst, 'reload schema';
