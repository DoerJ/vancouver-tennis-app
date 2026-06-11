alter table public.profiles
add column if not exists notifications uuid[] not null default '{}';

create or replace function public.delete_notification_for_current_user(
    notification_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    current_user_id uuid := auth.uid();
    current_recipients uuid[];
    remaining_recipients uuid[];
begin
    if current_user_id is null then
        raise exception 'Not authenticated';
    end if;

    update public.profiles
    set notifications = array_remove(
        coalesce(notifications, '{}'::uuid[]),
        notification_id
    )
    where id = current_user_id;

    select recipients
    into current_recipients
    from public.notifications
    where id = notification_id;

    if current_recipients is null then
        return;
    end if;

    remaining_recipients := array_remove(current_recipients, current_user_id);

    if cardinality(remaining_recipients) = 0 then
        delete from public.notifications
        where id = notification_id;
    else
        update public.notifications
        set
            recipients = remaining_recipients,
            read_by = array_remove(read_by, current_user_id),
            updated_at = now()
        where id = notification_id;
    end if;
end;
$$;

grant execute on function public.delete_notification_for_current_user(uuid) to authenticated;

notify pgrst, 'reload schema';
