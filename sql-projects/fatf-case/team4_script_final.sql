-- таблица со счётами
SELECT *
FROM "Account";

-- таблица с физ. лицами
SELECT *
FROM "Client_FL";

-- таблица с юр. лицами
SELECT *
FROM "Client_UL";

-- таблица с транзакциями
SELECT *
FROM "Transaction";


-- 1. Создадим 6 временных таблиц с настраиваемыми параметрами для проверки операций


-- 1.1. Таблица с основными параметрами

-- удалим таблицу, если она уже существует (чтобы избежать конфликта)
DROP TABLE IF EXISTS team4_script_parameters;

-- создадим временную таблицу с основными параметрами 
CREATE TEMP TABLE team4_script_parameters (MAX_AMOUNT_115 INT NOT NULL,						   -- порог суммы для обязательного контроля (в рублях) (Условие_8)
    									   RELEVANT_OPERATION_STATUS VARCHAR(32) NOT NULL);    -- статус операции, при котором она подлежит проверке (Условие_9)

-- заполним таблицу предустановленными значениями
INSERT INTO team4_script_parameters (MAX_AMOUNT_115, RELEVANT_OPERATION_STATUS)
VALUES (600000, 'ЗАВЕРШЕНА'); -- 600 000 RUB и статус "ЗАВЕРШЕНА"

-- вывод полей таблицы
SELECT *
FROM team4_script_parameters;


-- 1.2. Таблица для формирования текстового сообщения о срабатывании триггера;
-- текст формируется на основе битовых масок, а не CASE, для гибкости и масштабируемости

-- удалим таблицу, если она уже существует (чтобы избежать конфликта)
DROP TABLE IF EXISTS team4_trigger_text;

-- создадим временную таблицу 
CREATE TEMP TABLE team4_trigger_text (mask BIT(16) PRIMARY KEY,   -- битовая маска строки (один ненулевой бит)
									  text varchar(256)); 		  -- соответствующий текст
-- тип данных BIT(16) в PostgreSQL — это битовая строка фиксированной длины 16 бит (число с 16 цифрами в результате),
-- и он используется для хранения двоичных данных (0 и 1) (например, масок)

-- итак, заполним таблицу текстовыми фрагментами, соответствующим маскам;
-- маски задаются с помощью степеней двойки. Почему? Потому что создаются последовательности чисел, которые имеют единственный бит, равный 1, и все остальные биты равны 0;
-- Почему так? Потому что использование в маске только одного бита, равного 1, упрощает обработку и проверку условий
INSERT INTO team4_trigger_text VALUES (1::BIT(16), 'Банк-корреспондент зарегистрирован в стране, не участвующей в международном сообществе ПОД/ФТ.'),
									  (2::BIT(16), 'Получатель кредита'),
									  (4::BIT(16), 'Займодавец либо заемщик'),
									  (8::BIT(16), '(физ. лицо или ИП)'),
									  (16::BIT(16), '(юр. лицо)'),
									  -- описание статуса клиента по месту регистрации / проживания
									  (32::BIT(16), 'зарегистрирован(-о,-а)'),
									  (64::BIT(16), 'проживает'),
									  (128::BIT(16), 'зарегистрирован(-о,-а) и проживает'),
									  (256::BIT(16), 'находится'),
									  (512::BIT(16), 'зарегистрирован(-о,-а) и находится'),
									  (1024::BIT(16), 'проживает и находится'),
									  (2048::BIT(16), 'зарегистрирован(-о,-а), проживает и находится'),
									  -- географический признак
									  (4096::BIT(16), 'в стране, не участвующей в международном сообществе ПОД/ФТ.');
-- например, последняя маска 4096::BIT(16) обозначится во временной таблице числом 0001000000000000
-- в числе 0001000000000000 насчитывается 16 бит, где 15 битов равны 0, и 1 бит равен 1. Этот 1 бит — тринадцатый, если считать справа налево

-- вывод полей таблицы
SELECT *
FROM team4_trigger_text;


-- 1.3. Таблица с возможными странами для сценария;
-- страны, в которых возможен сценарий, указаны с использованием шаблонов '% ХХХ %',
-- что позволяет искать их в строках после очистки от небуквенных символов;
-- например, шаблон '% КНДР %' ищет строки, где есть слово "КНДР", окружённое пробелами или другими символами

-- удалим таблицу, если она уже существует (чтобы избежать конфликта)
DROP TABLE IF EXISTS team4_FATF_countries_list;

-- создадим временную таблицу 
CREATE TEMP TABLE team4_FATF_countries_list (country_name_mask varchar (64));   -- шаблон для поиска названия страны

-- заполним таблицу странами из списка Росфинмониторинга
INSERT INTO team4_FATF_countries_list VALUES ('% ИРАН %'),
											 ('% КНДР %'),
											 ('% СЕВЕРНАЯ КОРЕЯ %'),
											 ('% КОРЕЙСКАЯ НАРОДНАЯ ДЕМОКРАТИЧЕСКАЯ РЕСПУБЛИКА %');

-- вывод полей таблицы
SELECT *
FROM team4_FATF_countries_list;


-- 1.4. Таблица с кодами стран, для которых срабатывает сценарий;
-- используются шаблоны '% ХХХ %' для поиска соответствий
-- после очистки строки от небуквенных символов

-- удалим таблицу, если она уже существует (чтобы избежать конфликта)
DROP TABLE IF EXISTS team4_FATF_country_code_list;

-- создадим временную таблицу 
CREATE TEMP TABLE team4_FATF_country_code_list (country_code_mask varchar (7));   -- шаблон для поиска кода страны

-- заполненим таблицу кодами стран, попадающих под критерии Росфинмониторинга
INSERT INTO team4_FATF_country_code_list VALUES ('% IRN %'),    -- Иран
												('% PRK %');    -- КНДР (Северная Корея)

-- вывод полей таблицы
SELECT *
FROM team4_FATF_country_code_list;

												
-- 1.5. Таблица с шаблонами назначения платежа, связанных с получением кредита;
-- используются шаблоны '% ХХХ %' для поиска соответствий
-- после очистки строки от небуквенных символов

-- удалим таблицу, если она уже существует (чтобы избежать конфликта)
DROP TABLE IF EXISTS team4_credit_payment_purpose_list;

-- создадим временную таблицу
CREATE TEMP TABLE team4_credit_payment_purpose_list (payment_purpose_mask varchar (64));   -- Шаблон для поиска назначения платежа

-- заполним таблицу шаблонами, связанными с получением кредита
INSERT INTO team4_credit_payment_purpose_list VALUES ('% КРЕДИТ %'),
													 ('% ПОЛУЧЕНИЕ% КРЕДИТА %'),   -- найдет строки, где слово "ПОЛУЧЕНИЕ" стоит перед "КРЕДИТА", но между ними могут быть другие слова. Например, "ПОЛУЧЕНИЕ ЦЕЛЕВОГО КРЕДИТА".
													 ('% ВЫДАЧА% КРЕДИТА %'),
													 ('% ПРЕДОСТАВЛЕНИЕ% КРЕДИТА %'),
													 ('% РЕСТРУКТУРИЗАЦИЯ% КРЕДИТА %');

-- вывод полей таблицы
SELECT *
FROM team4_credit_payment_purpose_list;


-- 1.6. Таблица с шаблонами назначения платежа, связанными с получением займа;
-- используются шаблоны '% ХХХ %' для поиска соответствий
-- после очистки строки от небуквенных символов

DROP TABLE IF EXISTS team4_borrow_payment_purpose_list;

CREATE TEMP TABLE team4_borrow_payment_purpose_list (payment_purpose_mask varchar (64));   -- Шаблон для поиска назначения платежа

-- заполненим таблиц шаблонами, связанными с получением займа
INSERT INTO team4_borrow_payment_purpose_list VALUES ('% ЗАЙМ %'),
													 ('% ПОЛУЧЕНИЕ% ЗАЙМА %'),
													 ('% ВЫДАЧА% ЗАЙМА %'),
													 ('% ПРЕДОСТАВЛЕНИЕ% ЗАЙМА %'),
													 ('% РЕСТРУКТУРИЗАЦИЯ% ЗАЙМА %');

-- вывод полей таблицы
SELECT *
FROM team4_borrow_payment_purpose_list;


-- итак, 6 таблиц с настраиваемыми параметрами созданы



-- 2. Создадим 4 функции, каждая из которых: 1. очищает строку от небуквенных символов; 2. ищет очищенную строку по маске.
-- для удаления небуквенных символов и добавления пробелов будем использовать регулярные выражения 


-- 2.1. Функция проверки местоположения на соответствие странам, попадающим под международные стандарты ПОД/ФТ;
-- иными словами — функция проверяет, содержится ли указанное местоположение (location) в списке стран (поле country_name_mask временной таблицы team4_FATF_countries_list),
-- соответствующих международным стандартам ПОД/ФТ, и возвращает 1, если да, иначе 0

-- CREATE OR REPLACE FUNCTION создаёт или заменяет существующую функцию без ошибки, если она уже есть;
-- объявляем ф-ию is_in_FATF_list с параметром location типа varchar, которая возвращает (RETURNS) целое число из результата CASE (1 или 0 — булева логика);
-- тело функции заключено между AS $$ ... $$ LANGUAGE SQL
CREATE OR REPLACE FUNCTION is_in_FATF_list(location varchar)   -- CREATE OR REPLACE FUNCTION — создает новую функцию или заменяет существующую  
RETURNS integer AS $$     
	SELECT CASE
			   WHEN EXISTS (SELECT 1   -- вместо единицы можно указать любое числовое значение — это чисто символическое значение, ни на что не влияющее 
					    	FROM team4_FATF_countries_list
        					-- 1. ставим location в верхний регистр (UPPER);
							-- 2. оборачиваем (CONCAT) location пробелами с обеих сторон (для корректной работы % КНДР %);
							-- 3. заменяем (REGEXP_REPLACE) все небуквенные символы (\W+) на пробел (' '),
							-- параметр 'g' указывает на то, что замена должна быть выполнена глобально (по всей строке), а не только для первого совпадения;
							-- 4. проверяем (LIKE), совпадает ли очищенный location с шаблоном страны из team4_FATF_countries_list,
							-- если совпадает, то 1 (THEN 1), если нет, то — 0 (THEN 0)
    						WHERE REGEXP_REPLACE(CONCAT(' ', UPPER(location), ' '), '\W+', ' ', 'g') LIKE country_name_mask) THEN 1
    		   ELSE 0
		   END AS result;
$$ LANGUAGE SQL;


-- 2.2. Функция проверки кода страны на соответствие списку стран с критериями ПОД/ФТ
CREATE OR REPLACE FUNCTION is_in_FATF_CODE_list(country_code varchar)
RETURNS integer AS $$
    SELECT CASE
			   WHEN EXISTS (SELECT 1
    		                FROM team4_FATF_country_code_list
    		                WHERE REGEXP_REPLACE(CONCAT(' ', UPPER(country_code), ' '), '\W+', ' ', 'g') LIKE country_code_mask) THEN 1
    		   ELSE 0
		   END AS result;
$$ LANGUAGE SQL;


-- 2.3. Функция проверки назначения платежа по списку, связанному с получением кредита
CREATE OR REPLACE FUNCTION is_in_CREDIT_PURPOSE_list(payment_purpose varchar)
RETURNS integer AS $$
    SELECT CASE
			   WHEN EXISTS (SELECT 1
    			            FROM team4_credit_payment_purpose_list
   				            WHERE REGEXP_REPLACE(CONCAT(' ', UPPER(payment_purpose), ' '), '\W+', ' ', 'g') LIKE payment_purpose_mask) THEN 1
   			   ELSE 0 
		   END AS result;
$$ LANGUAGE SQL;


-- 2.4. Функция проверки назначения платежа по списку, связанному с получением займа
CREATE OR REPLACE FUNCTION is_in_BORROW_PURPOSE_list(payment_purpose varchar)
RETURNS integer AS $$
    SELECT CASE
			   WHEN EXISTS (SELECT 1
    		                FROM team4_borrow_payment_purpose_list
    		                WHERE REGEXP_REPLACE(CONCAT(' ', UPPER(payment_purpose), ' '), '\W+', ' ', 'g') LIKE payment_purpose_mask) THEN 1
    		   ELSE 0 
		   END AS result;
$$ LANGUAGE SQL;


-- итак, 4 функции созданы



-- 3. Создание основного запроса


-- 3.1. Подготовка CTE temporary_result1, включающей в себя:
-- А. маску trigger_text_mask;
-- Б. маску location_mask;
-- В. отбор операций в секции WHERE


-- 3.1.1. Подготовка маски trigger_text_mask, которая для каждой операции кодирует:
-- А. связь клиента со страной из списка ФАТФ;
-- Б. тип операции (кредит или займ);
-- В. статус клиента (физлицо/юрлицо).

-- исходные данные, которые участвуют в создании маски trigger_text_mask
SELECT counterparty_bank_country_code,     -- код страны банка контрагента
       t.payment_purpose,                  -- цель платежа
       cf.client_id                        -- идентификатор клиента
FROM "Transaction" AS t					   -- таблица с операциями		
LEFT JOIN "Client_FL" AS cf ON t.client_id = cf.client_id   -- присоединение таблицы физлицами
LEFT JOIN "Client_UL" AS cu ON t.client_id = cu.client_id,  -- присоединение таблицы с юрлицами
team4_script_parameters AS parameters                       -- присоединение таблицы с основными параметрами;

-- кодировка исходных данных в маску trigger_text_mask
SELECT is_in_FATF_CODE_list(t.counterparty_bank_country_code)::BIT(16)                    |   -- проверка кода страны банка-корреспондента       — результат 0000000000000001, если True
		                   (is_in_CREDIT_PURPOSE_list(t.payment_purpose)*2)::BIT(16)	  &   -- проверка, соответствует ли цель платежа кредиту — результат 0000000000000010, если True					 														
		                   ~(is_in_BORROW_PURPOSE_list(t.payment_purpose)*2)::BIT(16)	  |   -- и только для таких транзакций, где цель платежа исключительно кредит, а не кредит + займ																				
		                   (is_in_BORROW_PURPOSE_list(t.payment_purpose)*4)::BIT(16)	  |   -- проверка, соответствует ли цель платежа займу   — результат 0000000000000100, если True
		                   (CASE
			                    WHEN cf.client_id IS NOT NULL THEN 8                          -- проверка, клиент — физ. лицо?                   — результат 0000000000001000, если True
			                    ELSE 16                                                       -- иначе, клиент — юр. лицо                        — результат 0000000000010000
			                END)::BIT(16)	                                              |	 
		                   4096::BIT(16) AS trigger_text_mask								  -- завершение маски
FROM "Transaction" AS t										
LEFT JOIN "Client_FL" AS cf ON t.client_id = cf.client_id   -- присоединение таблицы физлицами 
LEFT JOIN "Client_UL" AS cu ON t.client_id = cu.client_id,  -- присоединение таблицы с юрлицами
team4_script_parameters AS parameters                       -- присоединение таблицы с основными параметрами;	
		              
-- чтобы лучше понимать результат запроса маски trigger_text_mask, возьмём одну запись, например 0001000000001011
-- по исходным данным можно расшифровать этот двоичный код: нас интересуют три единицы, занимающие первую, вторую и четвёртую позиции справа от 16-битного кода
-- первая единица означает код страны из списка ФАТФ, вторая — что операция с кредитом, четвёртая — это физ. лицо
-- на четвёртую единицу слева не нужно обращать внимание, потому что это технический флаг, указывающий на завершение маски

-- маска помогает эффективно кодировать различные условия транзакции в одном числовом значении для последующей обработки


-- 3.1.2. Подготовка маски location_mask, которая для каждой операции кодирует:
-- А. регистрацию клиента в стране ФАТФ (0000000000000001); 
-- Б. проживание клиента в стране ФАТФ (0000000000000010);
-- В. нахождение клиента в стране ФАТФ (0000000000000100).

-- исходные данные, которые участвуют в создании маски location_mask
SELECT cf.tax_registration_country,   -- код страны налогового резидентства ФЛ
	   cf.registration_address,		  -- прописка
	   cf.residential_address,		  -- место жительства
	   cf.postal_address,			  -- почтовый адрес
	   cu.tax_registration_country,   -- код страны налогового резидентства ЮЛ
	   cu.company_address,			  -- юридический адрес
	   cu.postal_address, 			  -- почтовый адрес ЮЛ
	   t.location AS location_mask	  -- местоположение, где проведена транзакция
FROM "Transaction" AS t										
LEFT JOIN "Client_FL" AS cf ON t.client_id = cf.client_id 
LEFT JOIN "Client_UL" AS cu ON t.client_id = cu.client_id,
team4_script_parameters AS parameters;

-- кодировка исходных данных в маску location_mask
SELECT is_in_FATF_CODE_list(cf.tax_registration_country)::BIT(16) |   -- проверка кода страны налогового резидентства ФЛ   — результат 0000000000000001, если True
	   is_in_FATF_list(cf.registration_address)::BIT(16)		  |   -- проверка прописки                                 — результат 0000000000000001, если True
	   (is_in_FATF_list(cf.residential_address)*2)::BIT(16)		  |   -- проверка места жительства                         — результат 0000000000000010, если True
	   (is_in_FATF_list(cf.postal_address)*4)::BIT(16)			  |   -- проверка почтового адреса                         — результат 0000000000000100, если True
	   is_in_FATF_CODE_list(cu.tax_registration_country)::BIT(16) |	  -- проверка кода страны налогового резидентства ЮЛ   — результат 0000000000000001, если True
	   is_in_FATF_list(cu.company_address)::BIT(16)				  |	  -- проверка юридического адреса                      — результат 0000000000000001, если True
	   (is_in_FATF_list(cu.postal_address)*4)::BIT(16) 			  |	  -- проверка почтового адреса ЮЛ                      — результат 0000000000000100, если True
	   (is_in_FATF_list(t.location)*4)::BIT(16) AS location_mask	  -- проверка местоположения, где проведена транзакция — результат 0000000000000100, если True
FROM "Transaction" AS t										
LEFT JOIN "Client_FL" AS cf ON t.client_id = cf.client_id 
LEFT JOIN "Client_UL" AS cu ON t.client_id = cu.client_id,
team4_script_parameters AS parameters;

-- так, если нам попадётся запись 0000000000000001 в маске location_mask, то тут 
-- видим одну единицу, которая может означать соответствие кода страны налогового резиденства ФЛ или ЮЛ со списком ФАТФ, 
-- либо совпадение прописки физлица или юридического адреса со списком ФАТФ


-- 3.1.3. Составление запроса с описанием секции WHERE, который будет входить во временную таблицу (CTE) temporary_result1

-- маска trigger_text_mask
SELECT is_in_FATF_CODE_list(t.counterparty_bank_country_code)::BIT(16)   |
	   (is_in_CREDIT_PURPOSE_list(t.payment_purpose)*2)::BIT(16)	     &			 														
	   ~(is_in_BORROW_PURPOSE_list(t.payment_purpose)*2)::BIT(16)	     |																				
	   (is_in_BORROW_PURPOSE_list(t.payment_purpose)*4)::BIT(16)	     |
	   (CASE
			WHEN cf.client_id IS NOT NULL THEN 8                           
			ELSE 16                                                        
		END)::BIT(16)	                                                 |	 
	   4096::BIT(16) AS trigger_text_mask,
-- маска location_mask
	   is_in_FATF_CODE_list(cf.tax_registration_country)::BIT(16)   |
	   is_in_FATF_list(cf.registration_address)::BIT(16)		    |
	   (is_in_FATF_list(cf.residential_address)*2)::BIT(16)		    |
	   (is_in_FATF_list(cf.postal_address)*4)::BIT(16)			    |
	   is_in_FATF_CODE_list(cu.tax_registration_country)::BIT(16)   |
	   is_in_FATF_list(cu.company_address)::BIT(16)				    |
	   (is_in_FATF_list(cu.postal_address)*4)::BIT(16) 			    |
	   (is_in_FATF_list(t.location)*4)::BIT(16) AS location_mask,
-- остальные требуемые поля согласно шаблону ТЗ
	   t.operation_id,										     -- идентификатор операции 
       COALESCE(cf.full_name, cu.company_name) as client_name,   -- имя физлица или название юрлица
	   t.operation_amount,									     -- сумма операции
	   t.currency												 -- валюта операции
FROM "Transaction" AS t
LEFT JOIN "Client_FL" AS cf ON t.client_id = cf.client_id
LEFT JOIN "Client_UL" AS cu ON t.client_id = cu.client_id,
team4_script_parameters AS parameters
-- КЛЮЧЕВАЯ ЧАСТЬ СЦЕНАРИЯ — ОТБОР ОПЕРАЦИЙ В СЕКЦИИ WHERE
WHERE CASE                                                                                               -- ГДЕ
		  WHEN UPPER(t.currency) LIKE '%RUB%' THEN t.operation_amount	                                 -- 1. сумма в рублях 
		  ELSE t.operation_amount * t.exchange_rate::FLOAT			                                     --    или валютном эквиваленте
	  END >= parameters.MAX_AMOUNT_115							                                         --    больше или равна 600000 рублям
  AND REGEXP_REPLACE(UPPER(t.operation_status), '\W+', '', 'g') = parameters.RELEVANT_OPERATION_STATUS   -- 2. И очищенный статус операции равен статусу "завершена"
  AND (is_in_CREDIT_PURPOSE_list(t.payment_purpose) = 1                                                  -- 3. И это кредит
   OR is_in_BORROW_PURPOSE_list(t.payment_purpose) = 1)	                                                 --    ЛИБО займ
-- Проверка страны клиента и банка по списку ФАТФ
-- для ФЛ:
  AND (is_in_FATF_CODE_list(cf.tax_registration_country) = 1                                             -- 4. И налоговая регистрация в КНДР или Иране
   OR is_in_FATF_list(cf.registration_address) = 1		                                                 --    ЛИБО прописка в КНДР или Иране
   OR is_in_FATF_list(cf.residential_address) = 1			                                             --    ЛИБО место жительства в КНДР или Иране
   OR is_in_FATF_list(cf.postal_address) = 1				                                             --    ЛИБО почтовый адрес в КНДР или Иране
-- для ЮЛ:
   OR is_in_FATF_CODE_list(cu.tax_registration_country) = 1                                              --    ЛИБО налоговая регистрация ЮЛ в КНДР или Иране
   OR is_in_FATF_list(cu.company_address) = 1					                                         --    ЛИБО юридический адрес в КНДР или Иране
   OR is_in_FATF_list(cu.postal_address) = 1 					                                         --    ЛИБО почтовый адрес в КНДР или Иране
-- для операций:
   OR is_in_FATF_CODE_list(t.counterparty_bank_country_code) = 1                                         --    ЛИБО банк-корреспондент в КНДР или Иране
   OR is_in_FATF_list(t.location) = 1)																	 --    ЛИБО клиент совершил транзакцию в КНДР или Иране



-- 3.2. Подготовка CTE temporary_result2, включающей в себя:
-- А. все поля из CTE temporary_result1;
-- Б. маску trigger_text_mask_with_location, объединяющую данные о транзакции и местоположении клиента;
-- В. маску location_clear_mask, скрывающую данные о клиенте, если его местоположение не соответствует странам из списка ФАТФ.
   
-- (SELECT *,   -- все поля из CTE temporary_result1	
--		   (1::BIT(16) << 4 + location_mask::INTEGER) | trigger_text_mask AS trigger_text_mask_with_location,
--		   CASE -- Если location_mask = 0, исключаем информацию о клиенте
--			   WHEN location_mask::INTEGER = 0 THEN 1::BIT(16) 	
--			   ELSE 65535::BIT(16)
--		   END AS location_clear_mask    						
--	FROM temporary_result1)
--
-- Как работает конструкция
-- "1::BIT(16) << 4 + location_mask::INTEGER) | trigger_text_mask AS trigger_text_mask_with_location"?
-- 1. выражение 1::BIT(16) << 4 + location_mask::INTEGER означает, что:
--    А. в значении 1::BIT(16), равном 0000000000000001
--    Б. мы сдвигаем бит (единицу) влево на (4 + location_mask::INTEGER) раз
--    так, например, если location_mask равно 0000000000000101, то в переводе на десятичную систему
--    это будет равно 5, так как:
--    0000000000000101 (двоичное) = 1*2^2 + 0*2^1 + 1*2^0
--                                = 4     + 0     + 1
--                                = 5 (десятичное)
--    следовательно, 1::BIT(16) << 4 + location_mask::INTEGER при location_mask = 0000000000000101 будет значить 0000001000000000
-- 2. к получившемуся значению 0000001000000000
--    мы просто прикладываем значение поля trigger_text_mask 0001000000001010,
--    и получаем 0001001000001010
--
-- Как работает конструкция CASE (маска location_clear_mask)
-- если location_mask::INTEGER равно 0, то location_clear_mask принимает значение 0000000000000001 (1::BIT(16)),
-- иначе location_clear_mask будет равно 1111111111111111 (65535::BIT(16))
-- 65535 — максимальное число, которое можно представить в 16 битах
   
-- кодировка исходных данных в маску location_mask
SELECT is_in_FATF_CODE_list(cf.tax_registration_country)::BIT(16) |
	   is_in_FATF_list(cf.registration_address)::BIT(16)		  |
	   (is_in_FATF_list(cf.residential_address)*2)::BIT(16)		  |
	   (is_in_FATF_list(cf.postal_address)*4)::BIT(16)			  |
	   is_in_FATF_CODE_list(cu.tax_registration_country)::BIT(16) |
	   is_in_FATF_list(cu.company_address)::BIT(16)				  |
	   (is_in_FATF_list(cu.postal_address)*4)::BIT(16) 			  |
	   (is_in_FATF_list(t.location)*4)::BIT(16) AS location_mask	  
FROM "Transaction" AS t										
LEFT JOIN "Client_FL" AS cf ON t.client_id = cf.client_id 
LEFT JOIN "Client_UL" AS cu ON t.client_id = cu.client_id,
team4_script_parameters AS parameters;
   
   
   
-- 4. Запрос целиком
WITH
-- CTE temporary_result1, включающая в себя:
-- А. маску trigger_text_mask;
-- Б. маску location_mask;
-- В. отбор операций в секции WHERE
					         -- маска trigger_text_mask, которая для каждой операции кодирует:
                             -- А. связь клиента со страной из списка ФАТФ;
                             -- Б. тип операции (кредит или займ);
                             -- В. статус клиента (физлицо/юрлицо).
temporary_result1 AS (SELECT is_in_FATF_CODE_list(t.counterparty_bank_country_code)::BIT(16) |   -- проверка кода страны банка-корреспондента       — результат 0000000000000001, если True
		                     (is_in_CREDIT_PURPOSE_list(t.payment_purpose)*2)::BIT(16)		 &   -- проверка, соответствует ли цель платежа кредиту — результат 0000000000000010, если True			 														
		                     ~(is_in_BORROW_PURPOSE_list(t.payment_purpose)*2)::BIT(16)		 |   -- и только для таких транзакций, где цель платежа исключительно кредит, а не кредит + займ			
		                     (is_in_BORROW_PURPOSE_list(t.payment_purpose)*4)::BIT(16)		 |   -- проверка, соответствует ли цель платежа займу   — результат 0000000000000100, если True
		                     (CASE
			                      WHEN cf.client_id IS NOT NULL THEN 8                           -- проверка, клиент — физ. лицо?                   — результат 0000000000001000, если True                           
			                      ELSE 16                                                        -- иначе, клиент — юр. лицо                        — результат 0000000000010000                                                        
			                  END)::BIT(16)	                                                 |	 
		                     4096::BIT(16) AS trigger_text_mask,								 -- завершение маски								 
		                     -- маска location_mask, которая для каждой операции кодирует:
 							 -- А. регистрацию клиента в стране ФАТФ; 
 							 -- Б. проживание клиента в стране ФАТФ;
 							 -- В. нахождение клиента в стране ФАТФ.
		                     is_in_FATF_CODE_list(cf.tax_registration_country)::BIT(16) |   -- проверка кода страны налогового резидентства ФЛ   — результат 0000000000000001, если True
		                     is_in_FATF_list(cf.registration_address)::BIT(16)		 	|   -- проверка прописки                                 — результат 0000000000000001, если True
		                     (is_in_FATF_list(cf.residential_address)*2)::BIT(16)		|   -- проверка места жительства                         — результат 0000000000000010, если True
		                     (is_in_FATF_list(cf.postal_address)*4)::BIT(16)			|   -- проверка почтового адреса                         — результат 0000000000000100, если True
		                     is_in_FATF_CODE_list(cu.tax_registration_country)::BIT(16) |	-- проверка кода страны налогового резидентства ЮЛ   — результат 0000000000000001, если True
		                     is_in_FATF_list(cu.company_address)::BIT(16)				|   -- проверка юридического адреса                      — результат 0000000000000001, если True
		                     (is_in_FATF_list(cu.postal_address)*4)::BIT(16) 			|   -- проверка почтового адреса ЮЛ                      — результат 0000000000000100, если True
		                     (is_in_FATF_list(t.location)*4)::BIT(16) AS location_mask,		-- проверка местоположения, где проведена транзакция — результат 0000000000000100, если True
							 -- требуемые поля согласно шаблону ТЗ
		                     t.operation_id,										   -- идентификатор операции 
    	                     COALESCE(cf.full_name, cu.company_name) as client_name,   -- имя физлица или название юрлица
		                     t.operation_amount,									   -- сумма операции
		                     t.currency												   -- валюта операции
	                  FROM "Transaction" AS t										   -- таблица операций
		              LEFT JOIN "Client_FL" AS cf ON t.client_id = cf.client_id 	   -- присоединение физлиц
		              LEFT JOIN "Client_UL" AS cu ON t.client_id = cu.client_id,	   -- присоединение юрлиц
		              team4_script_parameters AS parameters							   -- однострочная таблица параметров
-- КЛЮЧЕВАЯ ЧАСТЬ СЦЕНАРИЯ — ОТБОР ОПЕРАЦИЙ В СЕКЦИИ WHERE	
				      WHERE	CASE 																							   -- ГДЕ
					      	    WHEN UPPER(t.currency) LIKE '%RUB%' THEN t.operation_amount	                                   -- 1. сумма в рублях										
			                    ELSE t.operation_amount * t.exchange_rate::FLOAT			                                   --    или валютном эквиваленте
		                    END >= parameters.MAX_AMOUNT_115							                                       --    больше или равна 600000 рублям
	                    AND REGEXP_REPLACE(UPPER(t.operation_status), '\W+', '', 'g') = parameters.RELEVANT_OPERATION_STATUS   -- 2. И очищенный статус операции равен статусу "завершена"
				        AND (is_in_CREDIT_PURPOSE_list(t.payment_purpose) = 1 												   -- 3. И это кредит
				             OR is_in_BORROW_PURPOSE_list(t.payment_purpose) = 1)	 										   --    ЛИБО займ
				        -- Проверка страны клиента и банка по списку ФАТФ
				        	 -- для ФЛ:
						AND (is_in_FATF_CODE_list(cf.tax_registration_country) = 1                                             -- 4. И налоговая регистрация в КНДР или Иране
		                     OR is_in_FATF_list(cf.registration_address) = 1		 										   --    ЛИБО прописка в КНДР или Иране
		                     OR is_in_FATF_list(cf.residential_address) = 1			                                           --    ЛИБО место жительства в КНДР или Иране
		                     OR is_in_FATF_list(cf.postal_address) = 1				                                           --    ЛИБО почтовый адрес в КНДР или Иране
							 -- для ЮЛ:
	 	                     OR is_in_FATF_CODE_list(cu.tax_registration_country) = 1                                          --    ЛИБО налоговая регистрация ЮЛ в КНДР или Иране
		                     OR is_in_FATF_list(cu.company_address) = 1					                                       --    ЛИБО юридический адрес в КНДР или Иране
		                     OR is_in_FATF_list(cu.postal_address) = 1 					                                       --    ЛИБО почтовый адрес в КНДР или Иране
							 -- для операции:
                       		 OR is_in_FATF_CODE_list(t.counterparty_bank_country_code) = 1                                     --    ЛИБО банк-корреспондент в КНДР или Иране
                       		 OR is_in_FATF_list(t.location) = 1)), 							                                   --    ЛИБО клиент совершил транзакцию в КНДР или Иране
-- CTE temporary_result2, включающая в себя:
-- А. все поля из CTE temporary_result1;
-- Б. маску trigger_text_mask_with_location, объединяющую данные о транзакции и местоположении клиента;
-- В. маску location_clear_mask, скрывающую данные о клиенте, если его местоположение не соответствует странам из списка ФАТФ.
 temporary_result2 AS (SELECT *,   -- все поля из CTE temporary_result1			
		                      (1::BIT(16) << 4 + location_mask::INTEGER) | trigger_text_mask AS trigger_text_mask_with_location,
		                      CASE -- если location_mask = 0, исключаем информацию о клиенте
			                      WHEN location_mask::INTEGER = 0 THEN 1::BIT(16) 	
			                      ELSE 65535::BIT(16)
		                      END AS location_clear_mask    						
	                   FROM temporary_result1)
-- Финальный запрос: выводим сообщения, отфильтровав по маске
-- Собираем текстовые поля с помощью готовой двоичной маски и выводим результат запроса со всеми нужными полями
SELECT (SELECT string_agg(text, ' ')   -- функция собирает все значения из колонки text в одну строку
		FROM team4_trigger_text        -- из временной таблицы team4_trigger_text, разделяя их пробелами
		WHERE (mask & trigger_text_mask_with_location & location_clear_mask)::INTEGER != 0) AS message, -- где все 3 маски при переводе в десятичную систему не покажут 0
	    operation_id,
        client_name,
	    operation_amount,
	    currency
FROM temporary_result2;

-- главным образом сообщение (message) формируется исходя из совпадения битов колонки trigger_text_mask_with_location с 
-- битами колонки mask временной таблицы team4_trigger_text



-- удаляем все созданные объекты
DROP FUNCTION is_in_FATF_list;
DROP FUNCTION is_in_FATF_CODE_list;
DROP FUNCTION is_in_CREDIT_PURPOSE_list;
DROP FUNCTION is_in_BORROW_PURPOSE_list;

DROP TABLE IF EXISTS team4_script_parameters;
DROP TABLE IF EXISTS team4_trigger_text;
DROP TABLE IF EXISTS team4_FATF_countries_list;
DROP TABLE IF EXISTS team4_FATF_country_code_list;
DROP TABLE IF EXISTS team4_credit_payment_purpose_list;
DROP TABLE IF EXISTS team4_borrow_payment_purpose_list;