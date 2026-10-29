alter table public.players add column if not exists last_seen timestamptz not null default now();
alter table public.rooms add column if not exists game_mode text not null default 'coop';
alter table public.rooms add column if not exists question_ends_at timestamptz;
alter table public.rooms add column if not exists safe_false text;
alter table public.players add column if not exists blade int not null default 0;
alter table public.players add column if not exists armor int not null default 0;
alter table public.players add column if not exists points int not null default 0;
alter table public.players add column if not exists color text not null default '#48d7e5';
alter table public.players add column if not exists avatar text not null default '🦊';
alter table public.players add column if not exists team text not null default 'blue';
alter table public.players add column if not exists correct_count int not null default 0;

create or replace function public.join_game_balanced(p_room_id uuid,p_name text,p_color text,p_avatar text,p_preferred_team text default 'auto')
returns setof public.players language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); old_room uuid; bc int; rc int; chosen text;
begin
 if uid is null then raise exception 'Not authenticated'; end if;
 select room_id into old_room from players where id=uid;
 select count(*) filter(where team='blue'),count(*) filter(where team='red') into bc,rc from players where room_id=p_room_id and id<>uid;
 if p_preferred_team='blue' and bc<=rc then chosen:='blue';
 elsif p_preferred_team='red' and rc<=bc then chosen:='red';
 elsif bc<=rc then chosen:='blue'; else chosen:='red'; end if;
 if old_room is not null and old_room=p_room_id then
   update players set display_name=left(p_name,20),color=p_color,avatar=p_avatar,last_seen=now() where id=uid;
 else
   insert into players(id,room_id,display_name,color,avatar,team,hp,max_hp,xp,streak,torch,shield,potion,book,shield_active,blade,armor,points,correct_count)
   values(uid,p_room_id,left(p_name,20),p_color,p_avatar,chosen,5,5,0,0,1,1,1,1,false,0,0,0,0)
   on conflict(id) do update set room_id=excluded.room_id,display_name=excluded.display_name,color=excluded.color,avatar=excluded.avatar,team=excluded.team,hp=5,max_hp=5,xp=0,streak=0,torch=1,shield=1,potion=1,book=1,shield_active=false,blade=0,armor=0,points=0,correct_count=0,last_seen=now();
 end if;
 return query select * from players where id=uid;
end $$;
grant execute on function public.join_game_balanced(uuid,text,text,text,text) to authenticated;
