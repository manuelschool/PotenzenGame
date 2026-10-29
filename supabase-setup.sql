-- Run this entire file once in Supabase > SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.rooms (
 id uuid primary key default gen_random_uuid(),
 join_code text unique not null,
 host_id uuid not null,
 status text not null default 'lobby',
 question_no int not null default 0,
 question_text text,
 options jsonb,
 correct_answer text,
 explanation text,
 selected_answer text,
 safe_false text,
 question_ends_at timestamptz,
 monster_hp int not null default 20,
 monster_max_hp int not null default 20,
 created_at timestamptz not null default now()
);
create table if not exists public.players (
 id uuid primary key,
 room_id uuid not null references public.rooms(id) on delete cascade,
 display_name text not null check (char_length(display_name) between 1 and 20),
 hp int not null default 5, max_hp int not null default 5,
 xp int not null default 0, streak int not null default 0,
 blade int not null default 0, armor int not null default 0,
 torch int not null default 1, shield int not null default 1,
 potion int not null default 1, book int not null default 1,
 shield_active boolean not null default false,
 created_at timestamptz not null default now()
);
create table if not exists public.answers (
 id bigint generated always as identity primary key,
 room_id uuid not null references public.rooms(id) on delete cascade,
 question_no int not null,
 player_id uuid not null references public.players(id) on delete cascade,
 answer text not null,
 created_at timestamptz not null default now(),
 unique(room_id,question_no,player_id)
);

alter table public.rooms enable row level security;
alter table public.players enable row level security;
alter table public.answers enable row level security;

create policy "signed in can find rooms" on public.rooms for select to authenticated using (true);
create policy "host creates room" on public.rooms for insert to authenticated with check (host_id=auth.uid());
create policy "host updates room" on public.rooms for update to authenticated using (host_id=auth.uid()) with check (host_id=auth.uid());

create policy "room members see players" on public.players for select to authenticated using (true);
create policy "player joins as self" on public.players for insert to authenticated with check (id=auth.uid());
create policy "self or host updates player" on public.players for update to authenticated using (id=auth.uid() or exists(select 1 from public.rooms r where r.id=room_id and r.host_id=auth.uid()));

create policy "self or host reads answers" on public.answers for select to authenticated using (player_id=auth.uid() or exists(select 1 from public.rooms r where r.id=room_id and r.host_id=auth.uid()));
create policy "player submits own answer" on public.answers for insert to authenticated with check (player_id=auth.uid());
create policy "host clears answers" on public.answers for delete to authenticated using (exists(select 1 from public.rooms r where r.id=room_id and r.host_id=auth.uid()));

-- Realtime publication. Duplicate-object messages can be ignored if rerun.
alter publication supabase_realtime add table public.rooms;
alter publication supabase_realtime add table public.players;
alter publication supabase_realtime add table public.answers;

alter table public.rooms add column if not exists game_mode text not null default 'coop';
alter table public.rooms add column if not exists question_ends_at timestamptz;
alter table public.players add column if not exists blade int not null default 0;
alter table public.players add column if not exists armor int not null default 0;
alter table public.players add column if not exists points int not null default 0;
alter table public.players add column if not exists color text not null default '#48d7e5';
alter table public.players add column if not exists avatar text not null default '🦊';
alter table public.players add column if not exists team text not null default 'blue';
alter table public.players add column if not exists correct_count int not null default 0;

create or replace function public.join_game_balanced(p_room_id uuid,p_name text,p_color text,p_avatar text,p_preferred_team text default 'auto')
returns setof public.players language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); blue_count int; red_count int; chosen text;
begin
 if uid is null then raise exception 'Not authenticated'; end if;
 if exists(select 1 from players where id=uid) then
   update players set display_name=left(p_name,20),color=p_color,avatar=p_avatar where id=uid;
   return query select * from players where id=uid; return;
 end if;
 select count(*) filter(where team='blue'),count(*) filter(where team='red') into blue_count,red_count from players where room_id=p_room_id;
 if p_preferred_team='blue' and blue_count<=red_count then chosen:='blue';
 elsif p_preferred_team='red' and red_count<=blue_count then chosen:='red';
 elsif blue_count<=red_count then chosen:='blue'; else chosen:='red'; end if;
 insert into players(id,room_id,display_name,color,avatar,team) values(uid,p_room_id,left(p_name,20),p_color,p_avatar,chosen);
 return query select * from players where id=uid;
end $$;
grant execute on function public.join_game_balanced(uuid,text,text,text,text) to authenticated;
