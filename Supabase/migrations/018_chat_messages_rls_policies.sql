alter table public.chat_messages enable row level security;

drop policy if exists "Event members can view chat messages"
on public.chat_messages;

create policy "Event members can view chat messages"
on public.chat_messages
for select
to authenticated
using (
    exists (
        select 1
        from public.tennis_events event
        where event.id = chat_messages.event_id
          and (
              event.host_id = auth.uid()
              or auth.uid() = any(event.participants)
          )
    )
);

drop policy if exists "Event members can create chat messages"
on public.chat_messages;

create policy "Event members can create chat messages"
on public.chat_messages
for insert
to authenticated
with check (
    sender_id = auth.uid()
    and exists (
        select 1
        from public.tennis_events event
        where event.id = chat_messages.event_id
          and (
              event.host_id = auth.uid()
              or auth.uid() = any(event.participants)
          )
    )
);
