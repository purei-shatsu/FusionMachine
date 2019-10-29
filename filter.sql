--delete all aliases
delete from texts where id in (select id from datas where alias!=0);
delete from datas where alias!=0;

--delete all non-monsters
delete from texts where id in (select id from datas where type%2==0 or type==16401);
delete from datas where type%2==0 or type==16401;

--delete all ? atk/def monsters
delete from texts where id in (select id from datas where atk<0 or def<0);
delete from datas where atk<0 or def<0;

--set links monsters def to 0
update datas set def=0 where type==67108897;

--TODO remove tokens
