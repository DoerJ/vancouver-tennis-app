alter table public.profiles
add column if not exists hosted_events uuid[] not null default '{}';

create or replace function public.append_hosted_event_to_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    update public.profiles
    set
        hosted_events = case
            when new.id = any(hosted_events) then hosted_events
            else array_append(hosted_events, new.id)
        end,
        updated_at = now()
    where id = new.host_id;

    return new;
end;
$$;

drop trigger if exists append_hosted_event_to_profile on public.tennis_events;

create trigger append_hosted_event_to_profile
after insert on public.tennis_events
for each row
execute function public.append_hosted_event_to_profile();
