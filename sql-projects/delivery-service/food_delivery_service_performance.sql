-- 1. 
-- Проанализировать, насколько быстро растёт аудитория сервиса, посмотреть динамику числа пользователей и курьеров
-- Для каждого дня, представленного в таблицах user_actions и courier_actions, рассчитаны следующие показатели:
-- 1. Число новых пользователей.
-- 2. Число новых курьеров.
-- 3. Общее число пользователей на текущий день.
-- 4. Общее число курьеров на текущий день.
WITH 
--
-- число новых пользователей и общее число пользователей на текущий день
new_users AS (SELECT date,
                     new_users,
                     (SUM(new_users) OVER (ORDER BY date))::int AS total_users
              FROM (SELECT date,
                           COUNT(user_id) AS new_users
                    FROM (SELECT user_id,
                                 time::date AS date,
                                 ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY time) AS action_rank
                          FROM user_actions) AS t
                    WHERE action_rank = 1
                    GROUP BY date) AS t2),
-- 
-- число новых курьеров и общее число курьеров на текущий день
new_couriers AS (SELECT date,
                        new_couriers,
                        (SUM(new_couriers) OVER (ORDER BY date))::int AS total_couriers
                 FROM (SELECT date,
                              COUNT(courier_id) AS new_couriers
                       FROM (SELECT courier_id,
                                    time::date AS date,
                                    ROW_NUMBER() OVER (PARTITION BY courier_id ORDER BY time) AS action_rank
                             FROM courier_actions) AS t
                       WHERE action_rank = 1
                       GROUP BY date) AS t2)
--
SELECT nc.date,
       new_users,
       new_couriers,
       total_users,
       total_couriers
FROM new_couriers AS nc
INNER JOIN new_users AS nu ON nc.date = nu.date
ORDER BY date;
-- 1. Очевидно, что рост кол-ва пользователей превосходит рост кол-ва курьеров.
-- 2. У новых пользователей видим пики и впадины. У новых курьеров график кажется пологим, но если увеличить масштаб, то там не менее крутые неровности наблюдаются.
-- 3. Так что я бы не сказал, что показатель числа новых курьеров является более стабильным, чем показатель числа новых пользователей.



-- 2.
-- В прошлом запросе мы сравнивали абсолютные значения, что не очень удобно.
-- Посчитаем динамику пользователей и курьеров в относительных величинах.
-- Дополните предыдущий запрос и дополнительно рассчитаем следующие показатели:
-- 1. Прирост числа новых пользователей.
-- 2. Прирост числа новых курьеров.
-- 3. Прирост общего числа пользователей.
-- 4. Прирост общего числа курьеров.
WITH 
--
-- число новых пользователей и общее число пользователей на текущий день
new_users AS (SELECT date,
                     new_users,
                     (SUM(new_users) OVER (ORDER BY date))::int AS total_users
              FROM (SELECT date,
                           COUNT(user_id) AS new_users
                    FROM (SELECT user_id,
                                 time::date AS date,
                                 ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY time) AS action_rank
                          FROM user_actions) AS t
                    WHERE action_rank = 1
                    GROUP BY date) AS t2),
--
-- число новых курьеров и общее число курьеров на текущий день
new_couriers AS (SELECT date,
                        new_couriers,
                        (SUM(new_couriers) OVER (ORDER BY date))::int AS total_couriers
                 FROM (SELECT date,
                              COUNT(courier_id) AS new_couriers
                    FROM (SELECT courier_id,
                                    time::date AS date,
                                    ROW_NUMBER() OVER (PARTITION BY courier_id ORDER BY time) AS action_rank
                             FROM courier_actions) AS t
                    WHERE action_rank = 1
                    GROUP BY date) AS t2)
SELECT nc.date,
       new_users,
       new_couriers,
       total_users,
       total_couriers,
       ROUND((new_users::decimal / LAG(new_users) OVER (ORDER BY nc.date) - 1) * 100, 2) AS new_users_change,
       ROUND((new_couriers::numeric / LAG(new_couriers) OVER (ORDER BY nc.date) - 1) * 100, 2) AS new_couriers_change,
       ROUND((total_users::decimal / LAG(total_users) OVER (ORDER BY nc.date) - 1) * 100, 2) AS total_users_growth,
       ROUND((total_couriers::numeric / LAG(total_couriers) OVER (ORDER BY nc.date) - 1) * 100, 2) AS total_couriers_growth
FROM new_couriers AS nc
INNER JOIN new_users AS nu ON nc.date = nu.date
ORDER BY date;
-- 1. В целом, процент роста общего числа пользователей и курьеров идёт на спад с каждым днём.
-- 2. 31 августа, 4 и 7 сентября темп роста новых курьеров заметно опережал темп роста новых пользователей.
-- 3. Относительные показатели роста новых курьеров кажутся более волатильными по сравнению с показателями роста новых пользователей.



-- 3.
-- Теперь посмотрим на аудиторию сервиса под другим углом — посчитаем не просто всех пользователей, а именно ту часть, которая оформляет и оплачивает заказы в сервисе.
-- И выясним, какую долю платящие пользователи составляют от их общего числа.
-- Посчитаем курьеров, которые в определённый день приняли хотя бы один заказ, который был доставлен (возможно, уже на следующий день). Также выясним долю активных курьеров от общего числа.
-- Для каждого дня, представленного в таблицах user_actions и courier_actions, рассчитаем следующие показатели:
-- 1. Число платящих пользователей.
-- 2. Число активных курьеров.
-- 3. Долю платящих пользователей в общем числе пользователей на текущий день.
-- 4. Долю активных курьеров в общем числе курьеров на текущий день.
WITH
--
-- платящие пользователи
paying_users AS (SELECT time::date AS date,
                        COUNT(DISTINCT user_id) AS paying_users
                 FROM user_actions
                 WHERE order_id NOT IN (SELECT order_id
                                        FROM user_actions
                                        WHERE action = 'cancel_order')
                 GROUP BY date
                 ORDER BY date),
--
-- активные курьеры
active_couriers AS (SELECT time::date AS date,
                           COUNT(DISTINCT courier_id) AS active_couriers
                    FROM courier_actions
                    WHERE order_id IN (SELECT order_id
                                       FROM courier_actions
                                       WHERE action = 'deliver_order')
                    GROUP BY date
                    ORDER BY date),
--
-- число новых пользователей и общее число пользователей на текущий день
new_users AS (SELECT date,
                     new_users,
                     (SUM(new_users) OVER (ORDER BY date))::int AS total_users
              FROM (SELECT date,
                           COUNT(user_id) AS new_users
                    FROM (SELECT user_id,
                                 time::date AS date,
                                 ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY time) AS action_rank
                          FROM user_actions) AS t
                    WHERE action_rank = 1
                    GROUP BY date) AS t2),
--
-- число новых курьеров и общее число курьеров на текущий день
new_couriers AS (SELECT date,
                        new_couriers,
                        (SUM(new_couriers) OVER (ORDER BY date))::int AS total_couriers
                 FROM (SELECT date,
                              COUNT(courier_id) AS new_couriers
                    FROM (SELECT courier_id,
                                 time::date AS date,
                                 ROW_NUMBER() OVER (PARTITION BY courier_id ORDER BY time) AS action_rank
                          FROM courier_actions) AS t
                    WHERE action_rank = 1
                    GROUP BY date) AS t2)
SELECT pu.date,
       paying_users,
       active_couriers,
       ROUND(paying_users::decimal / total_users * 100, 2) AS paying_users_share,
       ROUND(active_couriers::decimal / total_couriers * 100, 2) AS active_couriers_share
FROM paying_users AS pu
INNER JOIN active_couriers AS ac ON pu.date = ac.date
INNER JOIN new_users AS nu ON pu.date = nu.date
INNER JOIN new_couriers AS nc ON pu.date = nc.date
ORDER BY date;
-- 1. Вместе с общим кол-вом пользователей и курьеров также растёт и число платящих пользователей и активных курьеров. Правда, 5 и 6 сентября у пользователей виден заметный спад.
-- 2. Думаю, показатели долей в целом закономерны. Главное, чтобы кол-во платящих пользователей стремилось к прямой пропорциональности росту кол-ву новых пользователей.



-- 4.
-- Как много платящих пользователей совершают более одного заказа в день?
-- Важно понимать, как ведут себя пользователи — они заходят в приложение,
-- чтобы сделать всего один заказ, или же сервис настолько хорош, что они готовы пользоваться им несколько раз в день?
WITH
--
-- пользователи, сделавшие в определённый день всего один заказ
one_order_users AS (SELECT date,
                           COUNT(user_id) AS one_order_users
                    FROM (SELECT time::date AS date,
                                 user_id,
                                 order_id,
                                 COUNT(order_id) OVER (PARTITION BY user_id, time::date ORDER BY time::date) AS orders_in_this_day
                          FROM user_actions
                          WHERE order_id NOT IN (SELECT order_id
                                                 FROM user_actions
                                                 WHERE action = 'cancel_order')) AS t
                    WHERE orders_in_this_day = 1
                    GROUP BY date),
--
-- пользователи, сделавшие в определённый день несколько заказов
several_orders_users AS (SELECT date,
                                COUNT(DISTINCT user_id) AS several_orders_users
                         FROM (SELECT time::date AS date,
                                      user_id,
                                      order_id,
                                      COUNT(order_id) OVER (PARTITION BY user_id, time::date ORDER BY time::date) AS orders_in_this_day
                               FROM user_actions
                               WHERE order_id NOT IN (SELECT order_id
                                                      FROM user_actions
                                                      WHERE action = 'cancel_order')) AS t
                         WHERE orders_in_this_day > 1
                         GROUP BY date
                         ORDER BY date),
--
-- платящие пользователи
paying_users AS (SELECT time::date AS date,
                        COUNT(DISTINCT user_id) AS paying_users
                 FROM user_actions
                 WHERE order_id NOT IN (SELECT order_id
                                        FROM user_actions
                                        WHERE action = 'cancel_order')
                 GROUP BY date
                 ORDER BY date)
SELECT date,
       ROUND(one_order_users::numeric / paying_users * 100, 2) AS single_order_users_share,
       ROUND(several_orders_users::decimal / paying_users * 100, 2) AS several_orders_users_share
FROM (SELECT oou.date,
             paying_users,
             one_order_users AS one_order_users,
             several_orders_users AS several_orders_users
      FROM one_order_users AS oou
      INNER JOIN several_orders_users AS sou ON oou.date = sou.date
      INNER JOIN paying_users AS pu ON oou.date = pu.date) AS t800
-- 1. Доля пользователей с несколькими заказами держится в среднем на уровне в 28,4%
-- 2. Думаю, это нормально, что в первый день доля пользоватетелей с несколькими заказами на особо низком уровне, так как в первый день положено распробовать продукцию


      
-- 5.
-- Расчёт показателей, связанных с заказами.
-- Для каждого дня, представленного в таблице user_actions, рассчитаны следующие показатели:
-- 1. Общее число заказов.
-- 2. Число первых заказов (заказов, сделанных пользователями впервые).
-- 3. Число заказов новых пользователей (заказов, сделанных пользователями в тот же день, когда они впервые воспользовались сервисом).
-- 4. Доля первых заказов в общем числе заказов (долю п.2 в п.1).
-- 5. Доля заказов новых пользователей в общем числе заказов (долю п.3 в п.1).
WITH
-- неотменённые заказы
committed_orders AS (SELECT user_id,
                            order_id,
                            action,
                            time
                     FROM user_actions
                     WHERE order_id NOT IN (SELECT order_id
                                            FROM user_actions
                                            WHERE action = 'cancel_order')),
-- всего заказов по дням
total_orders AS (SELECT time::date AS date,
                        COUNT(order_id) AS orders
                 FROM committed_orders
                 GROUP BY date
                 ORDER BY date),
-- заказы, сделанные пользователями впервые
first_orders AS (SELECT first_order_dt,
                        COUNT(user_id) AS first_orders
                 FROM (SELECT user_id,
                              MIN(time)::date AS first_order_dt
                       FROM committed_orders
                       GROUP BY user_id) AS t
                 GROUP BY first_order_dt
                 ORDER BY first_order_dt),
-- заказы, сделанные пользователями в тот же день, когда они впервые воспользовались сервисом
fresh_users_orders AS (SELECT time::date AS date,
                              COUNT(order_id) AS new_users_orders
                       FROM (SELECT user_id,
                                    order_id,
                                    time,
                                    action,
                                    DENSE_RANK() OVER (PARTITION BY user_id ORDER BY time::date) AS user_day_rank
                             FROM user_actions) AS t
                       WHERE order_id NOT IN (SELECT order_id
                                              FROM user_actions
                                              WHERE action = 'cancel_order')
                       AND user_day_rank = 1
                       GROUP BY date
                       ORDER BY date)
-- основной запрос
SELECT toto.date,
       orders,
       first_orders,
       new_users_orders,
       ROUND(first_orders::decimal / orders * 100, 2) AS first_orders_share,
       ROUND(new_users_orders::numeric / orders * 100, 2) AS new_users_orders_share
FROM total_orders AS toto
INNER JOIN first_orders AS fo ON toto.date = fo.first_order_dt
INNER JOIN fresh_users_orders AS fuo ON toto.date = fuo.date;
-- 1. В целом, абсолютные показатели растут. Лишь 5 и 6 сентября виден спад, но затем снова рост.
-- 2. Динамика относительных показателей закономерна, ведь с каждым днём всё большее кол-во пользователей делают всё больше и больше заказов, поэтому доли первых заказов и заказов новых пользователей уменьшаются



--6. 
-- Рассчитать по дням:
-- 1. Сколько платящих пользователей приходится на одного активного курьера?
-- 2. Сколько неотменённых заказов приходится на одного активного курьера?
WITH
-- платящие пользователи по дням
paying_users AS (SELECT time::date AS date,
                        COUNT(DISTINCT user_id) AS paying_users
                 FROM user_actions
                 WHERE order_id NOT IN (SELECT order_id
                                        FROM user_actions
                                        WHERE action = 'cancel_order')
                 GROUP BY date
                 ORDER BY date),
-- активные курьеры по дням
active_couriers AS (SELECT time::date AS date,
                           COUNT(DISTINCT courier_id) AS active_couriers
                    FROM courier_actions
                    WHERE order_id IN (SELECT order_id
                                       FROM courier_actions
                                       WHERE action = 'deliver_order')
                    GROUP BY date
                    ORDER BY date),
-- неотменённые заказы по дням
not_canceled_orders AS (SELECT creation_time::date AS date,
                               COUNT(order_id) AS not_canceled_orders
                        FROM orders
                        WHERE order_id NOT IN (SELECT order_id
                                               FROM user_actions
                                               WHERE action = 'cancel_order')
                        GROUP BY date
                        ORDER BY date)
-- основной запрос
SELECT date,
       ROUND(paying_users::decimal / active_couriers, 2) AS users_per_courier,
       ROUND(not_canceled_orders::numeric / active_couriers, 2) AS orders_per_courier
FROM (SELECT pu.date AS date,
             paying_users,
             active_couriers,
             not_canceled_orders
      FROM paying_users AS pu
      INNER JOIN active_couriers AS ac ON pu.date = ac.date
      INNER JOIN not_canceled_orders AS nco ON pu.date = nco.date) AS t
ORDER BY date;
-- 1. Видим, что динамика пользователей и заказов совпадает, ведь мы рассчитываем их относительно кол-ва активных курьеров.
-- 2. Рассматриваемые показатели скорее падают. В этом ничего плохого нет, ведь количество курьеров каждый день растёт.
-- 3. Думаю, у курьеров не большая нагрузка. 3 заказа в день в среднем на курьера это не много. Но не только на это нужно обращать внимание, чтобы делать такой вывод, конечно.



-- 7.
-- За сколько минут в среднем курьеры доставляли свои заказы каждый день?
SELECT deliver_dt::date AS date,
       ROUND(AVG(minutes_to_deliver))::int AS minutes_to_deliver
FROM (SELECT courier_id,
             order_id,
             action,
             accept_dt,
             time AS deliver_dt,
             EXTRACT(EPOCH FROM (time - accept_dt) / 60) AS minutes_to_deliver
      FROM (SELECT courier_id,
                   order_id,
                   action,
                   time,
                   LAG(time) OVER (PARTITION BY courier_id, order_id ORDER BY time) AS accept_dt
            FROM courier_actions
            WHERE order_id NOT IN (SELECT order_id
                                   FROM user_actions
                                   WHERE action = 'cancel_order')) AS t
      WHERE action = 'deliver_order') AS t2
GROUP BY date
ORDER BY date;
-- Получается, что в среднем клиенты ждут свой заказ 20 минут. И у курьеров получается придерживаться этого результата в течение всего периода



-- 8.
-- В какие часы пользователи оформляют больше всего заказов?
-- Как изменяется доля отмен в зависимости от времени оформления заказа?
WITH
-- кол-во доставленных заказов по часам
successful_orders AS (SELECT EXTRACT(HOUR FROM creation_time)::int AS hour,
                             COUNT(order_id) AS successful_orders
                      FROM orders
                      WHERE order_id IN (SELECT order_id
                                         FROM courier_actions
                                         WHERE action = 'deliver_order')
                      GROUP BY hour
                      ORDER BY hour),
-- кол-во отменённых заказов по часам
canceled_orders AS (SELECT EXTRACT(HOUR FROM creation_time)::int AS hour,
                           COUNT(order_id) AS canceled_orders
                    FROM orders
                    WHERE order_id IN (SELECT order_id
                                       FROM user_actions
                                       WHERE action = 'cancel_order')
                    GROUP BY hour
                    ORDER BY hour),
-- доля отменённых заказов от общего числа заказов
cancel_rate AS (SELECT so.hour AS hour,
                       successful_orders,
                       canceled_orders,
                       ROUND(canceled_orders::decimal / (successful_orders + canceled_orders), 3) AS cancel_rate
                FROM successful_orders AS so
                INNER JOIN canceled_orders AS co ON so.hour = co.hour)
-- основной запрос
SELECT hour,
       successful_orders,
       canceled_orders,
       cancel_rate
FROM cancel_rate
-- 1. Больше всего пользователи оформляют заказы в 19, 20, 21 час. Меньше всего — в 3, 4 часа ночи
-- 2. Связи между кол-вом оформляемых заказов и долей отменённых заказов нет. Cancel rate находится на стабильном уровне от 4.1% до 6%, в то время как кол-во заказов разительно отличается.
-- В вечерние часы показатель стремится ближе к 4.1% и офомляется заказов в эти часы больше всего.