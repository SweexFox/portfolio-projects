-- 1.
-- Общая сумма просмотров постов за каждый месяц 2008 года
SELECT DATE_TRUNC('month', creation_date)::date AS month,
       SUM(views_count) AS views
FROM stackoverflow.posts
WHERE EXTRACT(YEAR FROM creation_date) = 2008
GROUP BY month
ORDER BY views DESC;
-- данные отличаются, повышенная активность видна в сентябре и октябре. Возможно, это связано с началом учебного года. Просмотры в июле могут говорить о неполноте данных


-- 2.
-- Имена самых активных пользователей, которые в первый месяц после регистрации (включая день регистрации) дали больше 100 ответов.
-- Не учитываются вопросы, которые задавали пользователи. 
-- Для каждого имени пользователя выведено количество уникальных значений user_id
SELECT display_name,
       COUNT(DISTINCT user_id) AS user_ids
FROM stackoverflow.posts AS p
INNER JOIN stackoverflow.users AS u ON p.user_id = u.id
WHERE post_type_id IN (SELECT id
		       FROM stackoverflow.post_types
		       WHERE type = 'Answer')
  AND p.creation_date <= u.creation_date + INTERVAL '1 month'
GROUP BY 1
HAVING COUNT(post_type_id) > 100
ORDER BY display_name;
-- Видим, что одно и то же имя пользователя может принадлежать многим идентификаторам.
-- Следовательно, данные лучше анализировать имеено по id, а не по отображаемым именам.


-- 3.
-- Количество постов за 2008 год по месяцам от пользователей, которые зарегистрировались в сентябре 2008 года и сделали хотя бы один пост в декабре того же года
SELECT DATE_TRUNC('month', creation_date)::date AS month,
       COUNT(id)	   
FROM stackoverflow.posts
WHERE user_id IN (SELECT user_id
                  FROM (SELECT user_id,
	                       u.creation_date AS reg_date,
	                       p.creation_date AS post_date
                        FROM stackoverflow.users AS u
                        INNER JOIN stackoverflow.posts AS p ON u.id = p.user_id
                        WHERE u.creation_date::date BETWEEN '2008-09-01' AND '2008-09-30'
                        AND p.creation_date::date BETWEEN '2008-12-01' AND '2008-12-31'
                        ORDER BY 3) AS subquery)
GROUP BY month
ORDER BY month DESC;
-- есть аномальные значения: почему-то у пользователей, зарегистрировавшихся в сентябре, есть активность в августе. Возможна ошибка в данных


-- 4.
-- Несколько полей:
-- идентификатор пользователя, который написал пост;
-- дата создания поста;
-- количество просмотров у текущего поста;
-- сумму просмотров постов автора с накоплением
SELECT user_id,
       creation_date,
       views_count,
       SUM(views_count) OVER (PARTITION BY user_id ORDER BY creation_date) AS cum_sum
FROM stackoverflow.posts;


-- 5.
-- Сколько в среднем дней в период с 1 по 7 декабря 2008 года включительно пользователи взаимодействовали с платформой
WITH
days_per_user AS (SELECT user_id,
	                 COUNT(post_date) AS active_days
                  FROM (SELECT user_id,
	                       creation_date::date AS post_date
                        FROM stackoverflow.posts
                        WHERE creation_date::date BETWEEN '2008-12-01' AND '2008-12-07'
                        GROUP BY user_id,
		                 creation_date::date
                        ORDER BY user_id,
		                 creation_date::date) AS subquery
                  GROUP BY user_id)
SELECT ROUND(AVG(active_days)) AS av_days
FROM days_per_user;
-- следовательно, в период с 1 по 7 декабря 2008 года пользователи взаимодействовали с платформой в среднем 2 дня


-- 6.
-- На сколько процентов менялось количество постов ежемесячно с 1 сентября по 31 декабря 2008 года? 
-- Таблица со следующими полями:
-- номер месяца;
-- количество постов за месяц;
-- процент, который показывает, насколько изменилось количество постов в текущем месяце по сравнению с предыдущим
WITH
changes AS (SELECT *,
	           LAG(posts) OVER () AS last_month_posts
            FROM (SELECT EXTRACT(MONTH FROM creation_date) AS month_number,
	                 COUNT(id) AS posts
                  FROM stackoverflow.posts
                  WHERE creation_date BETWEEN '2008-09-01' AND '2008-12-31'
                  GROUP BY month_number) AS subquery)
SELECT month_number,
       posts,
       ROUND((posts::numeric / last_month_posts - 1) * 100, 2) AS percent_changes
FROM changes;


-- 7. 
-- Данные активности пользователя, который опубликовал больше всего постов за всё время. 
-- Выведены данные за октябрь 2008 года в таком виде:
-- номер недели;
-- дата и время последнего поста, опубликованного на этой неделе
WITH
usr_oct_actions AS (SELECT EXTRACT(WEEK FROM creation_date) AS week,
	                   creation_date,
	                   MAX(creation_date) OVER (PARTITION BY EXTRACT(WEEK FROM creation_date)) AS last_post_week
                    FROM stackoverflow.posts
                    WHERE user_id IN (SELECT user_id
                                      FROM (SELECT user_id,
	                                           COUNT(id) AS posts
                                            FROM stackoverflow.posts
                                            GROUP BY user_id
                                            ORDER BY posts DESC
                                            LIMIT 1) AS subquery)
                    AND creation_date::date BETWEEN '2008-10-01' AND '2008-10-31')
SELECT DISTINCT week,
       last_post_week
FROM usr_oct_actions
ORDER BY week;
