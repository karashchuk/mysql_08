-- Домашнее задание к уроку 8

-- 1. Добавить необходимые внешние ключи для всех таблиц базы данных vk (приложить команды).
ALTER TABLE profiles MODIFY COLUMN photo_id INT(10) UNSIGNED;

alter table profiles 
	add constraint profiles_user_id_fk
		foreign key (user_id) references users(id)
			on delete cascade,
	add constraint profiles_photo_id_fk
		foreign key (photo_id) references media(id)
			on delete set NULL;
ALTER TABLE profiles MODIFY COLUMN photo_id INT(10) UNSIGNED;

ALTER TABLE communities MODIFY COLUMN photo_id INT(10) UNSIGNED;

alter table communities 
	add constraint communities_photo_id_fk
		foreign key (photo_id) references media(id)
			on delete set NULL;

alter table communities_users 
	add constraint communities_users_community_id_fk
		foreign key (community_id) references communities(id)
			on delete cascade,	
	add constraint communities_users_user_id_fk
		foreign key (user_id) references users(id);
			
alter table friendship 
	add constraint friendship_user_id_fk
		foreign key (user_id) references users(id),
	add constraint friendship_friend_id_fk
		foreign key (friend_id) references users(id),
	add constraint friendship_status_id_fk
		foreign key (status_id) references friendship_statuses(id);
		
ALTER TABLE likes MODIFY COLUMN user_id INT(10) UNSIGNED;

alter table likes 
	add constraint likes_user_id_fk
		foreign key (user_id) references users(id)
			on delete set NULL,
	add constraint likes_target_type_id_fk
		foreign key (target_type_id) references target_types(id);
-- внешний ключ на поле target_id установить не получится так как там может ссылать на разные талицы, соответственно это должно решаться на уровне приложения
	
alter table media 
	add constraint media_user_id_fk
		foreign key (user_id) references users(id),
	add constraint media_media_type_id_fk
		foreign key (media_type_id) references media_types(id);
	
alter table meetings_users 
	add constraint meetings_users_user_id_fk
		foreign key (user_id) references users(id),
	add constraint meetings_users_meeting_id_fk
		foreign key (meeting_id) references meetings(id)
			on delete cascade;
		
ALTER TABLE messages
  ADD CONSTRAINT messages_from_user_id_fk 
    FOREIGN KEY (from_user_id) REFERENCES users(id),
  ADD CONSTRAINT messages_to_user_id_fk 
    FOREIGN KEY (to_user_id) REFERENCES users(id);
   
alter table posts 
	add constraint posts_user_id_fk
		foreign key (user_id) references users(id),
	add constraint posts_media_id_fk
		foreign key (media_id) references media(id)
			on delete set NULL;


-- 2. По созданным связям создать ER диаграмму, используя Dbeaver (приложить графический файл к ДЗ).

-- ER - диаграмма находится в файле ER_diagram_01.png


-- 3. Переписать запросы, заданые к ДЗ урока 6 с использованием JOIN (четыре запроса).

-- запрос 2 из урока 6. Пусть задан некоторый пользователь. 
-- Из всех друзей этого пользователя найдите человека, который больше всех общался 
-- с нашим пользователем.
SELECT 
	from_user_id,
	CONCAT(fu.first_name, ' ', fu.last_name) as username,
	to_user_id,
	count(*) as quantity 
from messages m
	left join users fu 
		on m.from_user_id = fu.id
	left join friendship fs
		on (m.from_user_id = fs.user_id and m.to_user_id =fs.friend_id) 
			or (m.from_user_id = fs.friend_id and m.to_user_id  = fs.user_id)
where to_user_id = 21
group by from_user_id 
ORDER BY quantity DESC 
LIMIT 1;

-- запрос 3 из урока 6. Подсчитать общее количество лайков, которые получили 10 самых молодых пользователей.

with youngs as
	(Select user_id from profiles ORDER by birthday DESC limit 10)
select 
	count(likes.id)
from likes
	left join target_types tt on target_type_id = tt.id 
	left join media m on target_id = m.id and tt.name like 'media'
	left join posts pst on target_id = pst.id and tt.name like 'posts'
	left join messages msg on target_id = msg.id and tt.name like 'messages'
	left join users u on target_id = u.id and tt.name like 'users'
where (m.user_id in (Select * from youngs))
	or (pst.user_id in (Select * from youngs)) 
	or (msg.from_user_id in (Select * from youngs)) 
	or (u.id in (Select * from youngs)) 
	;
	
-- еще одно решение с UNION:
with 
	youngs as
		(Select user_id from profiles ORDER by birthday DESC limit 10),
	acts as
		(
			(Select -- это сколько создали медиафайлов молодые пользователи 
				user_id,
				id as target_id, 
				(Select id FROM target_types where name like 'media') as target_type_id
			from media)
		UNION
			(Select -- это сколько создали посланий молодые пользователи 
				from_user_id as user_id,
				id as target_id, 
				(Select id FROM target_types where name like 'messages') as target_type_id
			from messages)
		UNION
			(Select  -- это сколько создали своих учеток молодые пользователи 
				id as user_id,
				id as target_id, 
				(Select id FROM target_types where name like 'users') as target_type_id
			from users)
		UNION
			(Select -- это сколько создали постов молодые пользователи 
				user_id,
				id as target_id, 
				(Select id FROM target_types where name like 'posts') as target_type_id
			from posts)
		)
Select count(id)
from likes l 
left join acts on acts.target_id = l.target_id and acts.target_type_id = l.target_type_id 
where acts.user_id in (Select * from youngs);

-- Запрос 4 из урока 6. Определить кто больше поставил лайков (всего) - мужчины или женщины?
Select 
	IF (p.sex = 'm','man','women'),
	count(l.id) as quantity
from likes l
left join profiles p on p.user_id = l.user_id 
group by p.sex 
order by quantity DESC;

-- Запрос 5 из урока 6. Найти 10 пользователей, которые проявляют наименьшую активность в использовании 
-- социальной сети.
-- под проявлением активности будем понимать: 
-- 1. создание постов
-- 2. создние медиа файлов
-- 3. создание сообщений
-- 4. создание лайков

select 
	u.id,
	CONCAT(u.first_name, ' ',u.last_name ) as username,
	(count(l.id) + Count(m.id) + count(p.id) + count(msg.id)) as qty
from users u 
	left join likes l on l.user_id = u.id
	left join media m on m.user_id  = u.id
	left join posts p on p.user_id  = u.id
	left join messages msg on msg.from_user_id  = u.id
group by u.id 
order by qty
limit 10
;

-- еще одно решение с UNION:
with  acts as
		((select 
			user_id, 
			id
		from posts)
	UNION	
		(select 
			user_id, 
			id
		from media)
	UNION	
		(select 
			from_user_id as user_id, 
			id
		from messages)
	UNION	
		(select 
			user_id, 
			id
		from likes))
select 
	user_id,
	CONCAT(first_name, ' ', last_name) as username,
	count(*) as qty
from acts
	left join users u on u.id = acts.user_id 
GROUP by user_id
ORDER by qty
LIMIT 10;
