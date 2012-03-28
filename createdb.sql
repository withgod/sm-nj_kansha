/*
drop database sourcemod;
create database sourcemod;
use sourcemod;
*/
/*
drop table nj_classes;
drop table nj_steamids;
drop table nj_steam_nicknames;
drop table nj_maps;
drop table nj_kansha_results;
*/
create table nj_classes(
	id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
	classid   int(11) NOT NULL,
	classname varchar(255) NOT NULL UNIQUE,
	created_at datetime DEFAULT NULL,
	updated_at datetime DEFAULT NULL
);

create table nj_steamids(
	id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
	steamid varchar(255) NOT NULL,
	steamcomid bigint(20) unsigned NOT NULL,
	created_at datetime DEFAULT NULL,
	updated_at datetime DEFAULT NULL,
	UNIQUE uq_steamid_steamcomid(steamid, steamcomid)
);

create table nj_steam_nicknames(
	id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
	nj_steamid_id int(11) NOT NULL,
	nickname varchar(255) NOT NULL,
	created_at datetime DEFAULT NULL,
	updated_at datetime DEFAULT NULL,
	UNIQUE uq_steamid_nickname(nj_steamid_id, nickname),
	FOREIGN KEY (nj_steamid_id) REFERENCES nj_steamids(id)
);

create table nj_maps(
	id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
	mapname varchar(255) not null UNIQUE,
	created_at datetime DEFAULT NULL,
	updated_at datetime DEFAULT NULL
);

create table nj_kansha_results(
	id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
	jump_count int(11) not null,
	nj_steamid_id INT(11) NOT NULL,
	nj_map_id INT(11) NOT NULL,
	nj_class_id INT(11) NOT NULL,
	tags text DEFAULT NULL,
	created_at datetime DEFAULT NULL,
	updated_at datetime DEFAULT NULL,
	FOREIGN KEY (nj_class_id) REFERENCES nj_classes(id),
	FOREIGN KEY (nj_steamid_id) REFERENCES nj_steamids(id),
	FOREIGN KEY (nj_map_id) REFERENCES nj_maps(id)
);
insert into nj_classes(classid, classname, created_at) values(1, 'Scout', now());
insert into nj_classes(classid, classname, created_at) values(2, 'Sniper', now());
insert into nj_classes(classid, classname, created_at) values(3, 'Soldier', now());
insert into nj_classes(classid, classname, created_at) values(4, 'Demoman', now());
insert into nj_classes(classid, classname, created_at) values(5, 'Medic', now());
insert into nj_classes(classid, classname, created_at) values(6, 'Pyro', now());
insert into nj_classes(classid, classname, created_at) values(7, 'Spy', now());
insert into nj_classes(classid, classname, created_at) values(8, 'Engineer', now());
/*
insert into nj_steamids(steamid, steamcomid, created_at) values('STEAM_0:0:18507580', 76561197997280888, now());
insert into nj_steamids(steamid, steamcomid, created_at) values('STEAM_0:1:21937045', 76561198004139819, now());
insert into nj_steam_nicknames(nj_steamid_id, nickname, created_at) values(1, 'withgod[hip]', now());
insert into nj_steam_nicknames(nj_steamid_id, nickname, created_at) values(1, 'hipman[hip]', now());
insert into nj_steam_nicknames(nj_steamid_id, nickname, created_at) values(1, '[nj]withgod', now());
insert into nj_steam_nicknames(nj_steamid_id, nickname, created_at) values(1, 'ひっぷまん[hip]', now());
insert into nj_steam_nicknames(nj_steamid_id, nickname, created_at) values(2, 'momiko', now());
insert into nj_maps(mapname, created_at) values('jump_littleman_fire', now());
insert into nj_maps(mapname, created_at) values('jump_beef', now());
insert into nj_maps(mapname, created_at) values('jump_quba', now());
*/
