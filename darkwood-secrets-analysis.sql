/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Тоскина Ульяна Алексеевна
 * Дата: 2025-10-19
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
WITH quantity AS( --CTE для подсчета пользователей
	SELECT 
	COUNT(id) AS total_users,
	COUNT(CASE
			WHEN payer = 1 THEN id
		END) AS paying_users
	FROM fantasy.users
)
SELECT 
	total_users,
	paying_users,
	ROUND(paying_users::numeric/total_users , 2) AS share --доля платящих от общего кол-ва
FROM quantity;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
WITH quantity AS( --CTE для подсчета пользователей с группировкой по расам
	SELECT 
	race_id,
	COUNT(id) AS total_race_users,
	COUNT(CASE
			WHEN payer = 1 THEN id
		END) AS paying_race_users
	FROM fantasy.users
	GROUP BY race_id 
)
SELECT 
	race_id,
	paying_race_users,
	total_race_users,
	ROUND(paying_race_users::numeric/total_race_users , 2) AS share --доля платящих от общего кол-ва внутри расы
FROM quantity;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT
	COUNT(transaction_id ) AS total_events,
	SUM(amount) AS total_amount,
	MIN(amount) AS min_amount,
	MAX(amount) AS max_amount,
	AVG(amount) AS avg_amount,
	PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY amount) AS median_amount,
	STDDEV(amount) AS stddev_amount
FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:
WITH quantity AS( --CTE для подсчета числа покупок
	SELECT 
	COUNT(*) AS total_events,
	COUNT(CASE
			WHEN amount = 0 THEN id
		END) AS for_free
	FROM fantasy.events
)
SELECT 
	total_events ,
	for_free ,
	for_free::numeric/total_events AS SHARE -- доля нулевых покупок от общего количества
FROM quantity;

-- 2.3: Популярные эпические предметы:
WITH not_for_free AS( -- таблица без нулевых покупок + названия предметов для анализа
	SELECT
		e.transaction_id,
		e.id,
		e.item_code,
		i.game_items AS item_name
	FROM fantasy.events AS e
	LEFT JOIN fantasy.items AS i
	ON e.item_code = i.item_code 
	WHERE amount <> 0
)
SELECT
	item_code,
	item_name,
	COUNT(transaction_id) AS absolute, -- общее количество продаж для каждого предмета
	COUNT(transaction_id)::numeric/SUM(COUNT(transaction_id)) OVER () AS relative, -- относительное значение (количество продаж предмета / общее количество продаж)
	COUNT(DISTINCT id)::numeric/(
		SELECT
			COUNT(DISTINCT id)
		FROM fantasy.events
		WHERE amount <> 0) AS popularity -- доля: игроки, купившие этот предмет / общее количество игроков-покупателей
FROM not_for_free
GROUP BY item_code, item_name -- популярность по предметам 
ORDER BY popularity DESC;

-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
WITH quantity AS(
	SELECT
		u.race_id,
		r.race,
		COUNT(DISTINCT u.id) AS total_users, -- количество зарегистрированных игроков 
		COUNT(DISTINCT e.id) AS buyers, -- количество игроков, совершающих внутриигровые покупки (информация о которых есть в events)
		COUNT(DISTINCT CASE
			WHEN u.payer = 1 THEN u.id
			END) AS paying_users, -- количество платящих игроков (у кого в таблице users payer = 1)
		COUNT(DISTINCT CASE
			WHEN u.payer = 1 AND e.id IS NOT NULL THEN u.id
			END) AS paying_buyers -- количество платящих, совершавших покупки для п.3
	FROM fantasy.users AS u
	LEFT JOIN fantasy.events AS e
	ON u.id = e.id AND e.amount <> 0 -- исключаем нулевые покупки
	INNER JOIN fantasy.race AS r
	ON u.race_id = r.race_id
	GROUP BY u.race_id, r.race
),
share AS(
	SELECT
		race_id,
		race,
		total_users,
		buyers,
		paying_users,
		paying_buyers,
		ROUND(buyers::numeric/ total_users, 3) AS buyers_from_users, -- доля игроков, совершающих покупки от общего количества пользователей
		ROUND(paying_buyers::numeric/ buyers, 2) AS paying_buyers_from_buyers -- доля платящих игроков среди игроков, совершающих покупки.
	FROM quantity
),
totals AS(
	SELECT
		u.race_id,
		COUNT(transaction_id) AS total_events,
		SUM(e.amount) AS total_amount,
		COUNT(DISTINCT u.id) AS buyers
	FROM fantasy.events AS e
	JOIN fantasy.users AS u
	ON e.id = u.id
	WHERE e.amount <> 0
	GROUP BY u.race_id	
),
stats AS(
	SELECT
		race_id,
		ROUND(total_events::numeric/ buyers, 2) AS avg_events_per_user, -- среднее количество покупок на одного игрока, совершившего внутриигровые покупки
		ROUND(total_amount::numeric/total_events, 2)  AS avg_amount_per_event_per_user, -- средняя стоимость одной покупки на одного игрока, совершившего внутриигровые покупки
		ROUND(total_amount::numeric/buyers,2) AS avg_sum_amount_per_user -- средняя суммарная стоимость всех покупок на одного игрока, совершившего внутриигровые покупки
	FROM totals
)
SELECT
	sh.race_id,
	sh.race,
	sh.total_users,
	sh.buyers,
	sh.paying_users,
	sh.paying_buyers,
	sh.buyers_from_users,
	sh.paying_buyers_from_buyers,
	st.avg_events_per_user,
	st.avg_amount_per_event_per_user,
	st.avg_sum_amount_per_user
FROM share AS sh
JOIN stats AS st
ON sh.race_id = st.race_id;

