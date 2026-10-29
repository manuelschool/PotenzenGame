alter table public.players add column if not exists last_seen timestamptz not null default now();
create or replace function public.remove_stale_players(p_room_id uuid,p_seconds int default 20)
returns int language plpgsql security definer set search_path=public as $$
declare removed int;
begin
 if not exists(select 1 from rooms where id=p_room_id and host_id=auth.uid()) then raise exception 'Host only'; end if;
 delete from players where room_id=p_room_id and last_seen < now()-make_interval(secs=>p_seconds);
 get diagnostics removed=row_count;return removed;
end $$;
grant execute on function public.remove_stale_players(uuid,int) to authenticated;
