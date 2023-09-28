-- 1.
-- Для каждого дня рассчитаны следующие показатели:
-- 1. Выручка, полученная в этот день.
-- 2. Суммарная выручка на текущий день.
-- 3. Прирост выручки, полученной в этот день, относительно значения выручки за предыдущий день.
--
WITH
-- подготовительная таблица
order_prices AS (SELECT DISTINCT order_id,
                        creation_time,
                        product_ids,
                        SUM(price) OVER (PARTITION BY order_id) AS order_price
                 FROM (SELECT *,
                              UNNEST(product_ids) AS product_id
                       FROM orders
                       WHERE order_id NOT IN (SELECT order_id
                                              FROM user_actions
                                              WHERE action = 'cancel_order')) AS o
                 INNER JOIN products AS p ON o.product_id = p.product_id),
-- выручка, полученная в определённый день
revenue_by_day AS (SELECT creation_time::date AS date,
                          SUM(order_price) AS revenue
                   FROM order_prices
                   GROUP BY date
                   ORDER BY date),
-- суммарная выручка на текущий день
total_revenue AS (SELECT date,
                         revenue,
                         SUM(revenue) OVER (ORDER BY date) AS total_revenue
                  FROM revenue_by_day)
-- прирост выручки, полученной в определённый день, относительно значения выручки за предыдущий день.
SELECT date,
       revenue,
       total_revenue,
       ROUND((revenue / LAG(revenue) OVER (ORDER BY date) - 1) * 100, 2) AS revenue_change
FROM total_revenue
ORDER BY date;
-- 5 и 6 сентября наблюдается заметное снижение ежедневной выручки. Вероятнее всего, это связано с резким спадом роста новых пользователей в эти дни.



-- 2.
-- Для каждого дня рассчитаны следующие показатели:
-- 1. Выручка на пользователя (ARPU).
-- 2. Выручка на платящего пользователя (ARPPU).
-- 3. Выручка с заказа, или средний чек (AOV).
--
WITH
-- заказы и их стоимости
order_prices AS (SELECT DISTINCT order_id,
                        creation_time,
                        product_ids,
                        SUM(price) OVER (PARTITION BY order_id) AS order_price
                 FROM (SELECT *,
                              UNNEST(product_ids) AS product_id
                       FROM orders
                       WHERE order_id NOT IN (SELECT order_id
                                              FROM user_actions
                                              WHERE action = 'cancel_order')) AS o
                 INNER JOIN products AS p ON o.product_id = p.product_id),
-- выручка, полученная в определённый день
revenue_by_day AS (SELECT creation_time::date AS date,
                          SUM(order_price) AS revenue
                   FROM order_prices
                   GROUP BY date
                   ORDER BY date),
-- всего пользователей
total_users AS (SELECT time::date AS date,
                       COUNT(DISTINCT user_id) AS total_users
                FROM user_actions
                GROUP BY date
                ORDER BY date),
-- платящие пользователи
paying_users AS (SELECT time::date AS date,
                        COUNT(DISTINCT user_id) AS paying_users
                 FROM user_actions
                 WHERE order_id NOT IN (SELECT order_id
                                        FROM user_actions
                                        WHERE action = 'cancel_order')
                 GROUP BY date
                 ORDER BY date),
-- всего оплаченных заказов
paid_orders AS (SELECT creation_time::date AS date,
                       COUNT(order_id) AS paid_orders
                FROM order_prices
                GROUP BY date
                ORDER BY date),
-- базовая таблица
basic_table AS (SELECT rbd.date,
                       revenue,
                       total_users,
                       paying_users,
                       paid_orders
                FROM revenue_by_day AS rbd
                INNER JOIN total_users AS tu ON rbd.date = tu.date
                INNER JOIN paying_users AS pu ON rbd.date = pu.date
                INNER JOIN paid_orders AS po ON rbd.date = po.date)
SELECT date,
       ROUND(revenue / total_users, 2) AS ARPU,
       ROUND(revenue / paying_users, 2) AS ARPPU,
       ROUND(revenue / paid_orders, 2) AS AOV
FROM basic_table;
--
-- У ARPU и ARPPU заметен разброс значений по сравнению с AOV
-- Тем не менее, я не уверен, можно ли посчтитать разницу в 110 рублей между самым злачным и наименее прибыльным днём аномальной.
-- Платящие и все пользователи имеют параллельные кривые. Кривые расположены близко друг к другу. Думаю, пользователи в целом охотно заказывают еду в сервисе.



-- 3.
-- Для каждого дня рассчитаны следующие показатели:
-- 1. Накопленная выручка на пользователя (Running ARPU)
-- 2. Накопленная выручка на платящего пользователя (Running ARPPU)
-- 3. Накопленная выручка с заказа, или средний чек (Running AOV)
--
WITH
-- заказы и их стоимости
order_prices AS (SELECT DISTINCT order_id,
                        creation_time,
                        product_ids,
                        SUM(price) OVER (PARTITION BY order_id) AS order_price
                 FROM (SELECT *,
                              UNNEST(product_ids) AS product_id
                       FROM orders
                       WHERE order_id NOT IN (SELECT order_id
                                              FROM user_actions
                                              WHERE action = 'cancel_order')) AS o
                 INNER JOIN products AS p ON o.product_id = p.product_id),
-- выручка, полученная в определённый день
revenue_by_day AS (SELECT creation_time::date AS date,
                          SUM(order_price) AS revenue
                   FROM order_prices
                   GROUP BY date
                   ORDER BY date),
-- новые пользователи по дням
new_users AS (SELECT date,
                     COUNT(user_id) AS new_users
              FROM (SELECT user_id,
                           time::date AS date,
                           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY time) AS action_rank
                    FROM user_actions) AS t
              WHERE action_rank = 1
              GROUP BY date),
-- новые платящие пользователи
new_paying_users AS (SELECT date,
                            COUNT(user_id) AS new_paying_users
                     FROM (SELECT user_id,
                                  time::date AS date,
                                  ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY time) AS action_rank
                           FROM user_actions
                           WHERE order_id NOT IN (SELECT order_id
                                                  FROM user_actions
                                                  WHERE action = 'cancel_order')) AS t
                     WHERE action_rank = 1
                     GROUP BY date),
-- всего оплаченных заказов
paid_orders AS (SELECT creation_time::date AS date,
                       COUNT(order_id) AS paid_orders
                FROM order_prices
                GROUP BY date
                ORDER BY date),
-- базовая таблица
basic_table AS (SELECT rbd.date,
                       revenue,
                       new_users,
                       new_paying_users,
                       paid_orders
                FROM revenue_by_day AS rbd
                INNER JOIN new_users AS nu ON rbd.date = nu.date
                INNER JOIN new_paying_users AS npu ON rbd.date = npu.date
                INNER JOIN paid_orders AS po ON rbd.date = po.date)
-- динамические ARPU, ARPPU, AOV
SELECT date,
       ROUND(SUM(revenue) OVER (ORDER BY date) / SUM(new_users) OVER (ORDER BY DATE), 2) AS running_arpu,
       ROUND(SUM(revenue) OVER (ORDER BY date) / SUM(new_paying_users) OVER (ORDER BY DATE), 2) AS running_arppu,
       ROUND(SUM(revenue) OVER (ORDER BY date) / SUM(paid_orders) OVER (ORDER BY DATE), 2) AS running_aov
FROM basic_table;
--
-- ARPU и ARPPU, очевидно, растут изо дня в день. А вот AOV стабильно балансирует на одном значении
-- Принимая во внимание динамику рассчитанных метрик, вполне возможно допустить, что со временем растёт число заказов на одного пользователя



-- 4.
-- Для каждого дня недели рассчитаны следующие показатели:
-- 1. Выручка на пользователя (ARPU).
-- 2. Выручка на платящего пользователя (ARPPU).
-- 3. Выручка с заказа, или средний чек (AOV).
--
WITH
-- заказы и их стоимости
order_prices AS (SELECT DISTINCT order_id,
                        creation_time,
                        product_ids,
                        SUM(price) OVER (PARTITION BY order_id) AS order_price
                 FROM (SELECT *,
                              UNNEST(product_ids) AS product_id
                       FROM orders
                       WHERE order_id NOT IN (SELECT order_id
                                              FROM user_actions
                                              WHERE action = 'cancel_order')) AS o
                 INNER JOIN products AS p ON o.product_id = p.product_id
                 WHERE creation_time::date BETWEEN '2022-08-26' AND '2022-09-08'),
-- выручка, полученная в определённый день
revenue_by_day AS (SELECT TO_CHAR(creation_time, 'Day') AS weekday,
                          EXTRACT(ISODOW FROM creation_time) AS weekday_number,
                          SUM(order_price) AS revenue
                   FROM order_prices
                   GROUP BY 1, 2
                   ORDER BY 2),
-- всего пользователей
total_users AS (SELECT TO_CHAR(time, 'Day') AS weekday,
                       EXTRACT(ISODOW FROM time) AS weekday_number,
                       COUNT(DISTINCT user_id) AS total_users
                FROM user_actions
                WHERE time::date BETWEEN '2022-08-26' AND '2022-09-08'
                GROUP BY 1, 2
                ORDER BY 2),
-- платящие пользователи
paying_users AS (SELECT TO_CHAR(time, 'Day') AS weekday,
                        EXTRACT(ISODOW FROM time) AS weekday_number,
                        COUNT(DISTINCT user_id) AS paying_users
                 FROM user_actions
                 WHERE order_id NOT IN (SELECT order_id
                                        FROM user_actions
                                        WHERE action = 'cancel_order')
                 AND time::date BETWEEN '2022-08-26' AND '2022-09-08'
                 GROUP BY 1, 2
                 ORDER BY 2),
-- всего оплаченных заказов
paid_orders AS (SELECT TO_CHAR(creation_time, 'Day') AS weekday,
                       EXTRACT(ISODOW FROM creation_time) AS weekday_number,
                       COUNT(order_id) AS paid_orders
                FROM order_prices
                GROUP BY 1, 2
                ORDER BY 2),
-- базовая таблица
basic_table AS (SELECT rbd.weekday,
                       rbd.weekday_number,
                       AVG(revenue) AS revenue,
                       AVG(total_users) AS total_users,
                       AVG(paying_users) AS paying_users,
                       AVG(paid_orders) AS paid_orders
                FROM revenue_by_day AS rbd
                INNER JOIN total_users AS tu ON rbd.weekday = tu.weekday
                INNER JOIN paying_users AS pu ON rbd.weekday = pu.weekday
                INNER JOIN paid_orders AS po ON rbd.weekday = po.weekday
                GROUP BY rbd.weekday,
                         rbd.weekday_number
                ORDER BY rbd.weekday_number)
-- основной запрос
SELECT weekday,
       weekday_number,
       ROUND(revenue / total_users, 2) AS arpu,
       ROUND(revenue / paying_users, 2) AS arppu,
       ROUND(revenue / paid_orders, 2) AS aov
FROM basic_table;
--
-- 1. В субботу и воскресенье ARPU и ARPPU приняли наибольшие значения. Вероятно, у пользователей более плотные заказы в выходные.
-- 2. Метрика AOV в выходные осталась на тех же показателях, что и в будние дни. Такое возможно благодаря равномерной и синхронной волатильности дохода и кол-ва заказов.



-- 5.
-- Для каждого дня рассчитаны следующие показатели:
-- 1. Выручка, полученная в этот день
-- 2. Выручка с заказов новых пользователей, полученная в этот день
-- 3. Доля выручки с заказов новых пользователей в общей выручке, полученной за этот день
-- 4. Доля выручки с заказов остальных пользователей в общей выручке, полученной за этот день
WITH
-- подготовительная таблица
order_prices AS (SELECT DISTINCT order_id,
                        creation_time,
                        product_ids,
                        SUM(price) OVER (PARTITION BY order_id) AS order_price
                 FROM (SELECT *,
                              UNNEST(product_ids) AS product_id
                       FROM orders
                       WHERE order_id NOT IN (SELECT order_id
                                              FROM user_actions
                                              WHERE action = 'cancel_order')) AS o
                 INNER JOIN products AS p ON o.product_id = p.product_id),
-- выручка, полученная в определённый день
revenue_by_day AS (SELECT creation_time::date AS date,
                          SUM(order_price) AS revenue
                   FROM order_prices
                   GROUP BY date
                   ORDER BY date),
-- выручка с новых пользователей, полученная в определённый день
new_users_revenue_by_day AS (SELECT time::date AS date,
                                    SUM(order_price) AS new_users_revenue
                             FROM (SELECT user_id,
                                          op.order_id,
                                          time,
                                          order_price,
                                          MIN(time::date) OVER (PARTITION BY user_id) AS first_day
                                   FROM user_actions AS ua
                                   LEFT OUTER JOIN order_prices AS op ON ua.order_id = op.order_id) AS t
                             WHERE first_day = time::date
                             GROUP BY date),
-- базовая таблица
base AS (SELECT rbd.date,
                revenue,
                new_users_revenue,
                revenue - new_users_revenue AS old_users_revenue
         FROM new_users_revenue_by_day AS nurbd
         JOIN revenue_by_day AS rbd ON nurbd.date = rbd.date),
-- готовая таблица
ready AS (SELECT date,
                 revenue,
                 new_users_revenue,
                 ROUND(new_users_revenue / revenue * 100, 2) AS new_users_revenue_share,
                 ROUND(old_users_revenue / revenue * 100, 2) AS old_users_revenue_share
          FROM base)
SELECT *
FROM ready;
-- Несмотря на то, что доля выручки от новых пользователей со временем становится всё ниже и ниже, доход от таких пользователей по-прежнему высок



-- 6.
-- Для каждого товара рассчитаны следующие показатели:
-- 1. Суммарная выручка, полученная от продажи этого товара за весь период
-- 2. Доля выручки от продажи этого товара в общей выручке, полученной за весь период
WITH
-- подготовительная таблица
all_the_products AS (SELECT name AS product_name,
                            SUM(price) AS revenue
                     FROM (SELECT *,
                                  UNNEST(product_ids) AS product_id
                           FROM orders
                           WHERE order_id NOT IN (SELECT order_id
                                                  FROM user_actions
                                                  WHERE action = 'cancel_order')) AS o
                     INNER JOIN products AS p ON o.product_id = p.product_id
                     GROUP BY name
                     ORDER BY revenue DESC),
-- продукт, доход с него, общая выручка
total_revenue AS (SELECT product_name,
                         revenue,
                         SUM(revenue) OVER () AS total_revenue
                  FROM all_the_products),
-- продукт, доход с него, доля от общей выручки
share_in_revenue AS (SELECT product_name,
                            revenue,
                            ROUND(revenue / total_revenue * 100, 2) AS share_in_revenue
                     FROM total_revenue),
-- переименовываем продукты в "ДРУГОЕ", доля у которых меньше 0.5%
other_products AS (SELECT CASE
                              WHEN share_in_revenue < 0.5 THEN 'ДРУГОЕ'
                          ELSE product_name
                          END AS product_name,
                          revenue,
                          share_in_revenue
                   FROM share_in_revenue),
-- группируем по продуктам и суммируем выручку с долями
completed AS (SELECT product_name,
                     SUM(revenue) AS revenue,
                     SUM(share_in_revenue) AS share_in_revenue
              FROM other_products
              GROUP BY product_name
              ORDER BY revenue DESC)
SELECT *
FROM completed;
--
-- В первых рядах затесалось всякого рода мясо. Эта группа оказалась бы на первом месте.

-- 7.
-- для каждого дня в таблицах orders и courier_actions рассчитаны следующие показатели:
-- 1. Выручка, полученная в этот день.
-- 2. Затраты, образовавшиеся в этот день.
-- 3. Сумма НДС с продажи товаров в этот день.
-- 4. Валовая прибыль в этот день (выручка за вычетом затрат и НДС).
-- 5. Суммарная выручка на текущий день.
-- 6. Суммарные затраты на текущий день.
-- 7. Суммарный НДС на текущий день.
-- 8. Суммарная валовая прибыль на текущий день.
-- 9. Доля валовой прибыли в выручке за этот день (долю п.4 в п.1).
-- 10. Доля суммарной валовой прибыли в суммарной выручке на текущий день (долю п.8 в п.5).
WITH
-- подготовительная таблица
order_prices AS (SELECT DISTINCT order_id,
                        creation_time,
                        product_ids,
                        SUM(price) OVER (PARTITION BY order_id) AS order_price
                 FROM (SELECT *,
                              UNNEST(product_ids) AS product_id
                       FROM orders
                       WHERE order_id NOT IN (SELECT order_id
                                              FROM user_actions
                                              WHERE action = 'cancel_order')) AS o
                 INNER JOIN products AS p ON o.product_id = p.product_id),
--
-- кол-во неотменённых заказов по дням
committed_orders AS (SELECT creation_time::date AS date,
                            COUNT(order_id) AS orders_cnt
                     FROM order_prices
                     GROUP BY date
                     ORDER BY date),
--
-- кол-во доставленных заказов каждого курьера по дням
courier_daily_activity AS (SELECT courier_id,
                                  date,
                                  daily_delivered_orders
                           FROM (SELECT courier_id,
                                        order_id,
                                        time::date AS date,
                                        COUNT(order_id) OVER (PARTITION BY courier_id, time::date) AS daily_delivered_orders
                                 FROM courier_actions
                                 WHERE order_id IN (SELECT order_id
                                                    FROM courier_actions
                                                    WHERE action = 'deliver_order')
                                 AND action = 'deliver_order') AS t
                           GROUP BY 1, 2, 3
                           ORDER BY 1, 2),
--
-- сколько денег мы платили курьерам каждый день
courier_daily_reward AS (SELECT courier_id,
                                date,
                                daily_delivered_orders,
                                daily_delivered_orders * 150 AS reward,
                                CASE
                                    WHEN daily_delivered_orders >= 5 AND EXTRACT(MONTH FROM date) = 8 THEN 400
                                    WHEN daily_delivered_orders >= 5 AND EXTRACT(MONTH FROM date) = 9 THEN 500
                                ELSE 0
                                END AS reward_for_quantity
                          FROM courier_daily_activity),
--
-- заказы с ценами на продукты и НДС
VAT AS (SELECT creation_time,
               name,
               price,
               CASE
                   WHEN name IN ('сахар', 'сухарики', 'сушки', 'семечки', 
                                 'масло льняное', 'виноград', 'масло оливковое', 
                                 'арбуз', 'батон', 'йогурт', 'сливки', 'гречка', 
                                 'овсянка', 'макароны', 'баранина', 'апельсины', 
                                 'бублики', 'хлеб', 'горох', 'сметана', 'рыба копченая', 
                                 'мука', 'шпроты', 'сосиски', 'свинина', 'рис', 
                                 'масло кунжутное', 'сгущенка', 'ананас', 'говядина', 
                                 'соль', 'рыба вяленая', 'масло подсолнечное', 'яблоки', 
                                 'груши', 'лепешка', 'молоко', 'курица', 'лаваш', 'вафли', 'мандарины') THEN ROUND(price / 110 * 10, 2)
                   ELSE ROUND(price / 120 * 20, 2)
               END AS VAT
        FROM (SELECT *,
                     UNNEST(product_ids) AS product_id
              FROM orders
              WHERE order_id NOT IN (SELECT order_id
                                     FROM user_actions
                                     WHERE action = 'cancel_order')) AS o
        INNER JOIN products AS p ON o.product_id = p.product_id),
--
-- Поле 2 — revenue. Выручка, полученная в определённый день
revenue_by_day AS (SELECT creation_time::date AS date,
                          SUM(order_price) AS revenue
                   FROM order_prices
                   GROUP BY date
                   ORDER BY date),
--
-- Поле 3.1 — costs. Постоянные издержки (затраты на аренду складских помещений)
constant_costs AS (SELECT date,
                          CASE
                              WHEN EXTRACT(MONTH FROM date) = 8 THEN 120000
                              WHEN EXTRACT(MONTH FROM date) = 9 THEN 150000
                          END AS constant_costs
                   FROM revenue_by_day),
--
-- Поле 3.2 — costs. Переменные издержки (затраты на сборку заказов)
variable_costs_1 AS (SELECT date,
                            CASE
                                WHEN EXTRACT(MONTH FROM date) = 8 THEN orders_cnt * 140
                                WHEN EXTRACT(MONTH FROM date) = 9 THEN orders_cnt * 115
                            END AS order_assembly_costs
                     FROM committed_orders),
--
-- Поле 3.3 — costs. Переменные издержки (затраты на довольствие курьеров)
variable_costs_2 AS (SELECT date,
                            courier_daily_reward + courier_daily_quantity_reward AS money_for_couriers
                     FROM (SELECT date,
                                  SUM(reward) AS courier_daily_reward,
                                  SUM(reward_for_quantity) AS courier_daily_quantity_reward
                            FROM courier_daily_reward
                            GROUP BY date
                            ORDER BY date) AS t),
--
-- Поле 3.4 — costs. Подсчёт всех затрат для каждого дня
costs AS (SELECT date,
                 constant_costs + order_assembly_costs + money_for_couriers AS costs
          FROM (SELECT cc.date,
                       constant_costs,
                       order_assembly_costs,
                       money_for_couriers
                FROM constant_costs AS cc
                JOIN variable_costs_1 AS vc1 ON cc.date = vc1.date
                JOIN variable_costs_2 AS vc2 ON cc.date = vc2.date) AS t),
--
-- Поле 4 — tax. Подсчёт суммы НДС с продажи товаров за каждый день
tax AS (SELECT creation_time::date AS date,
               SUM(vat) AS tax
        FROM VAT
        GROUP BY date),
--
-- Поле 5 - gross_profit. Подсчёт валовой прибыли (выручка за вычетом затрат и НДС) для каждого дня
gross_profit AS (SELECT rbd.date,
                        revenue - (costs + tax) AS gross_profit
                 FROM revenue_by_day AS rbd
                 JOIN costs AS c ON rbd.date = c.date
                 JOIN tax AS t ON rbd.date = t.date),
--
-- таблица с выручкой, затратами, суммами НДС и валовой прибылью по дням
rev_cos_tax_gross_table AS (SELECT rbd.date,
                                   revenue,
                                   costs,
                                   tax,
                                   gross_profit
                            FROM revenue_by_day AS rbd
                            JOIN costs AS c ON rbd.date = c.date
                            JOIN tax AS t ON rbd.date = t.date
                            JOIN gross_profit AS gp ON rbd.date = gp.date),
-- 
-- Поле 6 — total_revenue. Суммарная выручка на текущий день
-- Поле 7 — total_costs. Суммарные затраты на текущий день
-- Поле 8 — total_tax. Суммарный НДС на текущий день
-- Поле 9 — total_gross_profit. Суммарная валовая прибыль на текущий день
-- Поле 10 — gross_profit_ratio. Доля валовой прибыли в выручке за этот день (долю п.4 в п.1)
-- Поле 11 — total_gross_profit_ratio. Доля суммарной валовой прибыли в суммарной выручке на текущий день (долю п.8 в п.5)
the_main_table AS (SELECT date,
                          revenue,
                          costs,
                          tax,
                          gross_profit,
                          SUM(revenue) OVER (ORDER BY date) AS total_revenue,
                          SUM(costs) OVER (ORDER BY date) AS total_costs,
                          SUM(tax) OVER (ORDER BY date) AS total_tax,
                          SUM(gross_profit) OVER (ORDER BY date) AS total_gross_profit,
                          ROUND(gross_profit / revenue * 100, 2) AS gross_profit_ratio,
                          ROUND(SUM(gross_profit) OVER (ORDER BY date) / SUM(revenue) OVER (ORDER BY date) * 100, 2) AS total_gross_profit_ratio
                   FROM rev_cos_tax_gross_table
                   ORDER BY date)
SELECT *
FROM the_main_table;
--
-- 1. Только лишь 1-го сентября валовая прибыль стала положительной по итогу дня.
-- 2. Сервис вышел в плюс только 6-го сентября.
-- 3. В том числе и оптимизация стоимости сборки заказа позволила увидеть положительную валовую прибыль.