--delete from texts where id in (select id from datas where type not in (17, 4113, 65, 129));
--delete from datas where type not in (17, 4113, 65, 129);

--delete all alias
--delete all aliases
delete from texts where id in (select id from datas where alias!=0);
delete from datas where alias!=0;

--delete all non-monsters
delete from texts where id in (select id from datas where type%2==0 or type==16401);
delete from datas where type%2==0 or type==16401;

--delete all ? atk/def monsters
delete from texts where id in (select id from datas where atk<0 or def<0);
delete from datas where atk<0 or def<0;

/*
--delete all main deck effect monsters
delete from texts where id in (select id from datas where type in (33, 545, 1057, 2081, 4129, 2097185, 4194337, 16777249, 16777233, 67108897, 33554465, 33558561, 16385, 37748769, 16781345));
delete from datas where type in                                   (33, 545, 1057, 2081, 4129, 2097185, 4194337, 16777249, 16777233, 67108897, 33554465, 33558561, 16385, 37748769, 16781345);
*/

--set links monsters def to 0
update datas set def=0 where type==67108897;


