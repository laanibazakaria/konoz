-- اختبارات السلوك: النجوم، القطع، RLS، النشر، القيود. شغّلها عبر run_local.sh
\set ON_ERROR_STOP 0
insert into auth.users (id) values ('11111111-1111-1111-1111-111111111111'), ('22222222-2222-2222-2222-222222222222');
update profiles set role='editor' where id='22222222-2222-2222-2222-222222222222';

-- joueur
set role authenticated; set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
\echo '--- 1) niveau 1, 4/5 justes -> 2 étoiles, 40 pièces'
select * from submit_attempt(1, array[1,2,3,1,1]::smallint[]);
\echo '--- 2) rejouer avec moins bien -> 0 pièce, meilleur score conservé'
select * from submit_attempt(1, array[2,2,2,2,2]::smallint[]);
\echo '--- 3) parfait -> 3 étoiles, 50 pièces'
select * from submit_attempt(1, array[1,2,3,1,2]::smallint[]);
select level_id,best_stars,best_correct,attempts from level_progress;
\echo '--- 4) mauvais nombre de réponses -> erreur'
select * from submit_attempt(1, array[1,2]::smallint[]);
\echo '--- 5) joueur tente de se donner des pièces -> refusé'
update profiles set coins = 99999;
\echo '--- 6) joueur peut changer son nom'
update profiles set display_name='أحمد' returning display_name, coins;
\echo '--- 7) joueur tente d ecrire une question -> refusé (0 ligne / erreur)'
insert into questions (level_id,position,text_ar,choice_1,choice_2,choice_3,correct_choice) values (1,9,'x','a','b','c',1);
\echo '--- 8) joueur ne voit que les questions publiées'
reset role; update levels set is_published=false where id=3; set role authenticated;
select level_id, count(*) from questions group by 1 order by 1;
reset role; update levels set is_published=true where id=3;

-- éditeur
set role authenticated; set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
\echo '--- 9) éditeur crée un brouillon -> OK'
insert into questions (level_id,position,text_ar,choice_1,choice_2,choice_3,correct_choice) values (3,6,'سؤال','أ','ب','ج',2) returning status;
\echo '--- 10) éditeur tente de publier -> refusé'
update questions set status='published' where position=6 and level_id=3;
\echo '--- 11) choix identiques -> refusé'
insert into questions (level_id,position,text_ar,choice_1,choice_2,choice_3,correct_choice) values (3,7,'س','أ','أ','ج',1);
\echo '--- 12) correct_choice=4 -> refusé'
insert into questions (level_id,position,text_ar,choice_1,choice_2,choice_3,correct_choice) values (3,7,'س','أ','ب','ج',4);
\echo '--- 13) réordonner niveau 3'
select reorder_questions(3, (select array_agg(id order by position desc) from questions where level_id=3));
select position, left(text_ar,20) from questions where level_id=3 order by position;
\echo '--- 14) anon ne peut pas soumettre'
set role anon; select * from submit_attempt(1, array[1,2,3,1,2]::smallint[]);
