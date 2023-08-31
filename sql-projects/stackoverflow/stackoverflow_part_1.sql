-- 1. Количество вопросов, которые набрали больше 300 очков или как минимум 100 раз были добавлены в «Закладки»
SELECT COUNT(p.id)
FROM stackoverflow.posts AS p
INNER JOIN stackoverflow.post_types AS pt ON p.post_type_id = pt.id
WHERE type = 'Question'
 AND (score > 300
   OR favorites_count >= 100);


-- 2. Среднее количество заданных с 1 по 18 ноября 2008 года вопросов
SELECT ROUND(AVG(questions)) AS questions_per_day
FROM (SELECT creation_date::date,
	     COUNT(title) AS questions
      FROM stackoverflow.posts AS p
      INNER JOIN stackoverflow.post_types AS pt ON p.post_type_id = pt.id
      WHERE CAST(creation_date AS date) BETWEEN '2008-11-01' AND '2008-11-18'
        AND type = 'Question'
      GROUP BY creation_date::date) AS subquery;


-- 3. Количество уникальных пользователей, которые в день регистрации получили значки за достижения
SELECT COUNT(DISTINCT user_id) AS unique_users
FROM (SELECT u.id AS user_id,
	     name,
	     u.creation_date::date AS register_dt,
	     b.creation_date::date AS badge_dt
      FROM stackoverflow.users AS u
      INNER JOIN stackoverflow.badges AS b ON u.id = b.user_id
      WHERE u.creation_date::date = b.creation_date::date) AS subquery


-- 4. Количество уникальных постов пользователя с именем Joel Coehoorn, которые получили хотя бы один голос
SELECT COUNT(DISTINCT p.id)
FROM stackoverflow.posts AS p
INNER JOIN stackoverflow.votes AS v ON p.id = v.post_id
WHERE p.user_id IN (SELECT id
                    FROM stackoverflow.users
                    WHERE display_name = 'Joel Coehoorn')


-- 5. Все поля таблицы vote_types. К ней добавлено поле rank, в которое войдут номера записей в обратном порядке
SELECT *,
       ROW_NUMBER() OVER (ORDER BY id DESC) AS rank
FROM stackoverflow.vote_types
ORDER BY id;


-- 6. 10 пользователей, которые поставили больше всего голосов типа Close
SELECT user_id,
       COUNT(name) AS close_votes
FROM stackoverflow.votes AS v
INNER JOIN stackoverflow.vote_types AS vt ON v.vote_type_id = vt.id
WHERE name = 'Close'
GROUP BY user_id
ORDER BY close_votes DESC,
		 user_id DESC
LIMIT 10;


-- 7. 10 пользователей по количеству значков, полученных в период с 15 ноября по 15 декабря 2008 года включительно
SELECT *,
       DENSE_RANK() OVER (ORDER BY badges DESC) AS rank
FROM (SELECT user_id,
	         COUNT(id) AS badges
      FROM stackoverflow.badges
      WHERE creation_date::date BETWEEN '2008-11-15' AND '2008-12-15'
      GROUP BY user_id
      ORDER BY badges DESC,
		       user_id
      LIMIT 10) AS badges;


-- 8. Таблица из следующих полей:
-- заголовок поста;
-- идентификатор пользователя;
-- число очков поста;
-- среднее число очков пользователя за пост, округлённое до целого числа.
-- Не учитываются посты без заголовка, а также те, что набрали ноль очков
SELECT title,
       user_id,
       score,
       ROUND(AVG(score) OVER (PARTITION BY user_id)) AS avg_score
FROM stackoverflow.posts
WHERE title IS NOT NULL
  AND score <> 0;


-- 9. Заголовки постов, которые были написаны пользователями, получившими более 1000 значков. Посты без заголовков попадут в список
SELECT title
FROM stackoverflow.posts
WHERE user_id IN (SELECT user_id
                  FROM (SELECT user_id,
	                       COUNT(name) AS badges
                        FROM stackoverflow.badges
                        GROUP BY user_id
                        HAVING COUNT(name) > 1000
                        ORDER BY badges DESC) top_user)
AND title IS NOT NULL;


-- 10. Пользователи разделены на три группы в зависимости от кол-ва просмотров их профилей:
-- пользователям с числом просмотров больше либо равным 350 присвойте группу 1;
-- пользователям с числом просмотров меньше 350, но больше либо равно 100 — группу 2;
-- пользователям с числом просмотров меньше 100 — группу 3.
-- В таблицу попадут пользователи из США без нулевых просмотров профилей
SELECT id,
       views,
       CASE
       	   WHEN views >= 350 THEN 1
       	   WHEN views < 350 AND views >= 100 THEN 2
       	   WHEN views < 100 THEN 3
       END AS group
FROM stackoverflow.users
WHERE views <> 0
  AND location LIKE '%United States%';


-- 11. Из предыдущего запроса отображены лидеры каждой группы — пользователи, которые набрали максимальное число просмотров в своей группе 
WITH
t1 AS (SELECT id,
	      groups,
	      views,
	      MAX(views) OVER (PARTITION BY groups) AS max_views
       FROM (SELECT id,
                    views,
                    CASE
       	                WHEN views >= 350 THEN 1
       	                WHEN views < 350 AND views >= 100 THEN 2
       	                WHEN views < 100 THEN 3
                    END AS groups
             FROM stackoverflow.users
             WHERE views <> 0
             AND location LIKE '%United States%') AS subquery)
SELECT id,
       GROUPS,
       views
FROM t1
WHERE views = max_views
ORDER BY views DESC,
		 id;


-- 12. Ежедневный прирост новых пользователей в ноябре 2008 года
SELECT *,
       SUM(users) OVER (ORDER BY november_day) AS cum_sum
FROM (SELECT EXTRACT(DAY FROM creation_date::date) AS november_day,
	         COUNT(id) AS users
      FROM stackoverflow.users
      WHERE EXTRACT(YEAR FROM creation_date) = 2008
        AND EXTRACT(MONTH FROM creation_date) = 11
      GROUP BY 1) AS subquery;


-- 13. Интервал между регистрацией и временем создания первого поста для каждого пользователя, который написал хотя бы один пост
SELECT user_id,
       first_post_date - reg_date AS time_diff
FROM (SELECT user_id,
	     u.creation_date AS reg_date,
	     p.creation_date AS post_date,
	     FIRST_VALUE(p.creation_date) OVER(PARTITION BY user_id ORDER BY p.creation_date) AS first_post_date
      FROM stackoverflow.posts AS p
      INNER JOIN stackoverflow.users AS u ON p.user_id = u.id
      ORDER BY 1) AS subquery
WHERE first_post_date = post_date;
