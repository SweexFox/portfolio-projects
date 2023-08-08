-- Анализ данных. Запросы к базе данных, которая хранит информацию о венчурных фондах и инвестициях в компании-стартапы

-- 1. Сколько компаний закрылось
SELECT COUNT(id) AS closed_companies
FROM company
WHERE status = 'closed';


-- 2. Количество привлечённых средств для новостных компаний США
SELECT funding_total
FROM company
WHERE category_code = 'news'
  AND country_code = 'USA'
ORDER BY funding_total DESC;


-- 3. Общая сумма сделок по покупке одних компаний другими в долларах. Отобраны сделки, которые осуществлялись только за наличные с 2011 по 2013 год включительно
SELECT SUM(price_amount) AS total_sum
FROM acquisition
WHERE term_code = 'cash'
  AND EXTRACT(YEAR FROM acquired_at) BETWEEN 2011 AND 2013;
        
             
-- 4. Имя, фамилия, названия аккаунтов людей в твиттере, у которых названия аккаунтов начинаются на 'Silver'
SELECT first_name,
       last_name,
       twitter_username
FROM people
WHERE twitter_username LIKE 'Silver%';


-- 5. Вся информация о людях, у которых названия аккаунтов в твиттере содержат подстроку 'money', а фамилия начинается на 'K'
SELECT *
FROM people
WHERE twitter_username LIKE '%money%'
  AND last_name LIKE 'K%';
  
 
-- 6. Сумма привлечённых инвестиций компаний по странам
SELECT country_code,
       SUM(funding_total) AS funding_total
FROM company
GROUP BY country_code
ORDER BY funding_total DESC;


-- 7. Даты проведения раундов с минимальным и максимальным значениями суммы инвестиций, привлечёнными в эту дату.
--    В итоговой таблице только те записи, в которых минимальное значение суммы инвестиций не равно нулю и не равно максимальному значению.
SELECT funded_at,
       MIN(raised_amount),
       MAX(raised_amount)
FROM funding_round
GROUP BY funded_at
HAVING MIN(raised_amount) <> 0
   AND MIN(raised_amount) <> MAX(raised_amount);

  
-- 8. Все поля таблицы fund и новое поле с категориями:
--    для фондов, которые инвестируют в 100 и более компаний, назначена категория high_activity;
--	  для фондов, которые инвестируют в 20 и более компаний до 100, назначена категория middle_activity;
--    если количество инвестируемых компаний фонда не достигает 20, назначена категория low_activity.
SELECT *,
       CASE
           WHEN invested_companies >= 100 THEN 'high_activity'
           WHEN invested_companies >= 20
            AND invested_companies < 100 THEN 'middle_activity'
           ELSE 'low_activity'
       END AS activity_category
FROM fund;


-- 9. Категории и округлённое среднее количество инвестиционных раундов, в которых фонд принимал участие
SELECT CASE
           WHEN invested_companies >= 100 THEN 'high_activity'
           WHEN invested_companies >= 20
            AND invested_companies < 100 THEN 'middle_activity'
           ELSE 'low_activity'
       END AS activity_category,
       ROUND(AVG(investment_rounds)) AS avg_investment_rounds
FROM fund
GROUP BY activity_category
ORDER BY avg_investment_rounds;


-- 10. В каких странах находятся фонды, которые чаще всего инвестируют в стартапы. 
SELECT country_code,
       MIN(invested_companies) AS min_invested_companies,
       MAX(invested_companies) AS max_invested_companies,
       AVG(invested_companies) AS avg_invested_companies
FROM fund
WHERE EXTRACT(YEAR FROM founded_at) BETWEEN 2010 AND 2012
GROUP BY country_code
HAVING MIN(invested_companies) <> 0
ORDER BY avg_invested_companies DESC,
         country_code
LIMIT 10;


-- 11. Имя, фамилия всех сотрудников стартапов и название учебного заведения, которое окончил сотрудник
SELECT first_name,
       last_name,
       instituition
FROM people AS p
LEFT OUTER JOIN education AS e ON p.id = e.person_id;


-- 12. Топ-5 компаний и число уникальных учебных заведений, которые окончили их сотрудники
WITH 
tt AS (SELECT sub.id AS com_id,
              name,
              p.id AS people_id
       FROM (SELECT *
             FROM company) AS sub
       LEFT OUTER JOIN people AS p ON sub.id = p.company_id)
SELECT name AS company_name,
       COUNT(DISTINCT instituition) AS instituition_count
FROM tt
LEFT OUTER JOIN education AS e ON tt.people_id = e.person_id
GROUP BY name
ORDER BY instituition_count DESC
LIMIT 5;


-- 13. Уникальные названия закрытых компаний, для которых первый раунд финансирования оказался последним
SELECT DISTINCT name AS company_name
FROM company AS c
INNER JOIN funding_round AS fr ON c.id = fr.company_id
WHERE status = 'closed'
  AND is_first_round = 1
  AND is_last_round = 1;


-- 14. Уникальные ID сотрудников, которые работают в компаниях, отобранных в предыдущем запросе
SELECT DISTINCT employee_id
FROM (SELECT name AS company_name,
             p.id AS employee_id
      FROM company AS c
      INNER JOIN people AS p ON c.id = p.company_id
      WHERE name IN (SELECT DISTINCT name AS company_name
                     FROM company AS c
                     INNER JOIN funding_round AS fr ON c.id = fr.company_id
                     WHERE status = 'closed'
                       AND is_first_round = 1
                       AND is_last_round = 1)) AS sub;

                      
-- 15. Уникальные пары с номерами сотрудников из предыдущего запроса и учебным заведением, которое окончил сотрудник
SELECT employee_id,
       instituition
FROM (SELECT name AS company_name,
             p.id AS employee_id
      FROM company AS c
      INNER JOIN people AS p ON c.id = p.company_id
      WHERE name IN (SELECT DISTINCT name AS company_name
                     FROM company AS c
                     INNER JOIN funding_round AS fr ON c.id = fr.company_id
                     WHERE status = 'closed'
                       AND is_first_round = 1
                       AND is_last_round = 1)) AS sub
INNER JOIN education AS e ON sub.employee_id = e.person_id
GROUP BY employee_id,
         instituition;

        
-- 16. Количество учебных заведений для каждого сотрудника из предыдущего запроса с учётом, что некоторые сотрудники могли окончить одно и то же заведение дважды
SELECT employee_id,
       COUNT(instituition) AS instituitions
FROM (SELECT name AS company_name,
             p.id AS employee_id
      FROM company AS c
      INNER JOIN people AS p ON c.id = p.company_id
      WHERE name IN (SELECT DISTINCT name AS company_name
                     FROM company AS c
                     INNER JOIN funding_round AS fr ON c.id = fr.company_id
                     WHERE status = 'closed'
                       AND is_first_round = 1
                       AND is_last_round = 1)) AS sub
INNER JOIN education AS e ON sub.employee_id = e.person_id
GROUP BY employee_id;


-- 17. Среднее число всех учебных заведений, которые окончили сотрудники разных компаний
SELECT AVG(instituitions) AS avg_instituitions
FROM (SELECT employee_id,
             COUNT(instituition) AS instituitions
      FROM (SELECT name AS company_name,
                   p.id AS employee_id
            FROM company AS c
            INNER JOIN people AS p ON c.id = p.company_id
            WHERE name IN (SELECT DISTINCT name AS company_name
                           FROM company AS c
                           INNER JOIN funding_round AS fr ON c.id = fr.company_id
                           WHERE status = 'closed'
                             AND is_first_round = 1
                             AND is_last_round = 1)) AS sub
      INNER JOIN education AS e ON sub.employee_id = e.person_id
      GROUP BY employee_id) AS avg;


-- 18. Среднее число учебных заведений, которые окончили сотрудники Facebook
SELECT AVG(instituitions) AS avg_instituitions
FROM (SELECT p.id,
             COUNT(instituition) AS instituitions
      FROM people AS p
      INNER JOIN education AS e ON p.id = e.person_id
      WHERE company_id IN (SELECT id
                           FROM company
                           WHERE name = 'Facebook')
      GROUP BY p.id) AS subq;


-- 19. Название фонда, название компании и сумма инвестиций, которую привлекла компания в раунде.
-- В историях компаний было больше шести важных этапов, а раунды финансирования проходили с 2012 по 2013 год включительно
SELECT f.name AS name_of_fund,
       c.name AS name_of_company,
       raised_amount AS amount
FROM investment AS i
INNER JOIN company AS c ON i.company_id = c.id
INNER JOIN fund AS f ON i.fund_id = f.id
INNER JOIN funding_round AS fr ON i.funding_round_id = fr.id
WHERE c.milestones > 6
  AND EXTRACT(YEAR FROM funded_at) BETWEEN 2012 AND 2013;
 
 
-- 20. 5 полей: 
-- 1. название компании-покупателя;
-- 2. сумма сделки;
-- 3. название компании, которую купили;
-- 4. сумма инвестиций, вложенных в купленную компанию;
-- 5. доля, которая отображает, во сколько раз сумма покупки превысила сумму вложенных в компанию инвестиций, округлённая до ближайшего целого числа
-- Не учитываются те сделки, в которых сумма покупки равна нулю. Не включены такие компании, у которых сумма инвестиций в них равна нулю. 
SELECT c1.name AS acquiring_company_name,
       price_amount,
       c2.name AS acquired_company_name,
       c2.funding_total,
       ROUND(price_amount / c2.funding_total) AS ratio
FROM acquisition AS a
LEFT OUTER JOIN company AS c1 ON a.acquiring_company_id = c1.id
LEFT OUTER JOIN company AS c2 ON a.acquired_company_id = c2.id
WHERE price_amount <> 0
  AND c2.funding_total <> 0
ORDER BY price_amount DESC,
         acquired_company_name
LIMIT 10;


-- 21. 2 поля:
-- 1. названия компаний из категории social, получившие финансирование с 2010 по 2013 год включительно, сумма инвестиций не равна нулю;
-- 2. номер месяца, в котором проходил раунд финансирования
SELECT name AS company_name,
       EXTRACT(MONTH FROM funded_at) AS round_month
FROM company AS c
INNER JOIN funding_round AS fr ON c.id = fr.company_id
WHERE category_code = 'social'
  AND EXTRACT(YEAR FROM funded_at) BETWEEN 2010 AND 2013
  AND raised_amount <> 0;
  
  
-- 22.  4 поля:
-- 1. номер месяца, в котором проходили раунды;
-- 2. количество уникальных названий фондов из США, которые инвестировали в этом месяце;
-- 3. количество компаний, купленных за этот месяц;
-- 4. общая сумма сделок по покупкам в этом месяце
-- Данные по месяцам с 2010 по 2013 год, когда проходили инвестиционные раунды
WITH
tt1 AS (SELECT EXTRACT(MONTH FROM acquired_at) AS month,
               COUNT(acquired_company_id) AS acquired_companies,
               SUM(price_amount) AS total_sum
        FROM acquisition
        WHERE EXTRACT(YEAR FROM acquired_at) BETWEEN 2010 AND 2013
        GROUP BY 1),                                
tt2 AS (SELECT id AS funding_round_id,
               EXTRACT(MONTH FROM funded_at) AS month
        FROM funding_round
        WHERE EXTRACT(YEAR FROM funded_at) BETWEEN 2010 AND 2013),                 
tt3 AS (SELECT funding_round_id,
               name
        FROM fund AS f
        INNER JOIN investment AS i ON f.id = i.fund_id
        WHERE country_code = 'USA'),
tt4 AS (SELECT month,
               COUNT(DISTINCT name) AS unique_funds
        FROM tt2
        INNER JOIN tt3 ON tt2.funding_round_id = tt3.funding_round_id
        GROUP BY 1)
SELECT tt4.month,
       tt4.unique_funds,
       tt1.acquired_companies,
       tt1.total_sum
FROM tt1
INNER JOIN tt4 ON tt1.month = tt4.MONTH;


-- 23. Средняя сумма инвестиций для стран, в которых есть стартапы, зарегистрированные в 2011, 2012 и 2013 годах
WITH 
y_2011 AS (SELECT country_code AS country,
                  AVG(funding_total) AS avg_funding_2011
           FROM company
           WHERE EXTRACT(YEAR FROM founded_at) = 2011
           GROUP BY country_code),
y_2012 AS (SELECT country_code AS country,
                  AVG(funding_total) AS avg_funding_2012
           FROM company
           WHERE EXTRACT(YEAR FROM founded_at) = 2012
           GROUP BY country_code),
y_2013 AS (SELECT country_code AS country,
                  AVG(funding_total) AS avg_funding_2013
           FROM company
           WHERE EXTRACT(YEAR FROM founded_at) = 2013
           GROUP BY country_code)   
SELECT y_2011.country,
       y_2011.avg_funding_2011,
       y_2012.avg_funding_2012,
       y_2013.avg_funding_2013
FROM y_2011
INNER JOIN y_2012 ON y_2011.country = y_2012.country
INNER JOIN y_2013 ON y_2011.country = y_2013.country
ORDER BY avg_funding_2011 DESC;
