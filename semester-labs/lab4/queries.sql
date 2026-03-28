-- Лабораторная работа 4. 10 осмысленных запросов по расширенной структуре.
-- Требование: каждый запрос использует >= 3 таблиц.
-- Используются: подзапросы, группировки, оконные функции.

-- 1) Топ-10 пассажиров по милям (оконная функция)
SELECT la.passenger_id,
       t.passenger_name,
       la.total_miles,
       DENSE_RANK() OVER (ORDER BY la.total_miles DESC) AS miles_rank
FROM semester_ext.loyalty_accounts la
JOIN tickets t ON t.passenger_id = la.passenger_id
JOIN ticket_flights tf ON tf.ticket_no = t.ticket_no
GROUP BY la.passenger_id, t.passenger_name, la.total_miles
ORDER BY miles_rank, t.passenger_name
LIMIT 10;

-- 2) Начисленные мили по маршрутам (группировка)
SELECT d.city ->> 'ru' AS from_city,
       a.city ->> 'ru' AS to_city,
       SUM(lo.miles) AS total_miles_earned
FROM semester_ext.loyalty_operations lo
JOIN flights f ON f.flight_id = lo.flight_id
JOIN airports_data d ON d.airport_code = f.departure_airport
JOIN airports_data a ON a.airport_code = f.arrival_airport
WHERE lo.operation_type = 'EARN'
GROUP BY from_city, to_city
ORDER BY total_miles_earned DESC
LIMIT 20;

-- 3) Рейсы с учетом мест сотрудников и пассажирской загрузки
SELECT f.flight_id,
       f.flight_no,
       COUNT(DISTINCT bp.ticket_no) AS boarded_passengers,
       COUNT(DISTINCT eo.employee_no) AS employee_onboard
FROM flights f
LEFT JOIN boarding_passes bp ON bp.flight_id = f.flight_id
LEFT JOIN semester_ext.employee_seat_occupancy eo ON eo.flight_id = f.flight_id
GROUP BY f.flight_id, f.flight_no
ORDER BY employee_onboard DESC, boarded_passengers DESC
LIMIT 20;

-- 4) Частые смены места в полете по пассажирам (подзапрос + группировка)
SELECT x.passenger_id,
       x.passenger_name,
       x.change_count
FROM (
    SELECT t.passenger_id,
           t.passenger_name,
           COUNT(*) AS change_count
    FROM semester_ext.inflight_seat_changes sc
    JOIN tickets t ON t.ticket_no = sc.ticket_no
    JOIN flights f ON f.flight_id = sc.flight_id
    GROUP BY t.passenger_id, t.passenger_name
) x
WHERE x.change_count >= 2
ORDER BY x.change_count DESC, x.passenger_name;

-- 5) Выручка по маршрутам и средний чек (группировка)
SELECT d.city ->> 'ru' AS from_city,
       a.city ->> 'ru' AS to_city,
       COUNT(*) AS segments,
       SUM(tf.amount) AS revenue,
       ROUND(AVG(tf.amount), 2) AS avg_segment_price
FROM ticket_flights tf
JOIN flights f ON f.flight_id = tf.flight_id
JOIN airports_data d ON d.airport_code = f.departure_airport
JOIN airports_data a ON a.airport_code = f.arrival_airport
GROUP BY from_city, to_city
ORDER BY revenue DESC
LIMIT 20;

-- 6) Кандидаты на уровень лояльности по порогам (окно + case)
SELECT la.passenger_id,
       t.passenger_name,
       la.total_miles,
       CASE
           WHEN la.total_miles >= 100000 THEN 'Platinum'
           WHEN la.total_miles >= 50000 THEN 'Gold'
           WHEN la.total_miles >= 20000 THEN 'Silver'
           ELSE 'Base'
       END AS suggested_level,
       PERCENT_RANK() OVER (ORDER BY la.total_miles) AS pct_rank
FROM semester_ext.loyalty_accounts la
JOIN tickets t ON t.passenger_id = la.passenger_id
JOIN ticket_flights tf ON tf.ticket_no = t.ticket_no
GROUP BY la.passenger_id, t.passenger_name, la.total_miles
ORDER BY la.total_miles DESC
LIMIT 30;

-- 7) Пассажиры с высокими тратами и низкими милями (подзапрос)
WITH avg_m AS (
    SELECT AVG(total_miles) AS avg_miles FROM semester_ext.loyalty_accounts
), spend AS (
    SELECT t.passenger_id,
           t.passenger_name,
           SUM(tf.amount) AS total_spend
    FROM tickets t
    JOIN ticket_flights tf ON tf.ticket_no = t.ticket_no
    JOIN flights f ON f.flight_id = tf.flight_id
    GROUP BY t.passenger_id, t.passenger_name
)
SELECT s.passenger_id,
       s.passenger_name,
       s.total_spend,
       la.total_miles
FROM spend s
JOIN semester_ext.loyalty_accounts la ON la.passenger_id = s.passenger_id
CROSS JOIN avg_m
WHERE s.total_spend > (SELECT AVG(total_spend) FROM spend)
  AND la.total_miles < avg_m.avg_miles
ORDER BY s.total_spend DESC;

-- 8) Задержки по маршрутам и ранг в паре городов (окно)
SELECT d.city ->> 'ru' AS from_city,
       a.city ->> 'ru' AS to_city,
       f.flight_id,
       (f.actual_departure - f.scheduled_departure) AS dep_delay,
       RANK() OVER (
           PARTITION BY d.city ->> 'ru', a.city ->> 'ru'
           ORDER BY (f.actual_departure - f.scheduled_departure) DESC NULLS LAST
       ) AS delay_rank_in_pair
FROM flights f
JOIN airports_data d ON d.airport_code = f.departure_airport
JOIN airports_data a ON a.airport_code = f.arrival_airport
WHERE f.actual_departure IS NOT NULL
ORDER BY dep_delay DESC NULLS LAST
LIMIT 50;

-- 9) Срез занятых мест (сотрудники + пассажиры) по рейсам
SELECT f.flight_id,
       f.flight_no,
       COUNT(DISTINCT bp.seat_no) AS passenger_seats,
       COUNT(DISTINCT eo.seat_no) AS employee_seats,
       COUNT(DISTINCT bp.seat_no) + COUNT(DISTINCT eo.seat_no) AS total_occupied
FROM flights f
LEFT JOIN boarding_passes bp ON bp.flight_id = f.flight_id
LEFT JOIN semester_ext.employee_seat_occupancy eo ON eo.flight_id = f.flight_id
GROUP BY f.flight_id, f.flight_no
ORDER BY total_occupied DESC
LIMIT 20;

-- 10) Дневная сводка рейсов и активности бонусной программы
SELECT date_trunc('day', f.scheduled_departure) AS day_dt,
       COUNT(DISTINCT f.flight_id) AS flights_cnt,
       COUNT(DISTINCT tf.ticket_no) AS sold_tickets_cnt,
       COALESCE(SUM(CASE WHEN lo.operation_type = 'EARN' THEN lo.miles ELSE 0 END), 0) AS earned_miles
FROM flights f
LEFT JOIN ticket_flights tf ON tf.flight_id = f.flight_id
LEFT JOIN semester_ext.loyalty_operations lo ON lo.flight_id = f.flight_id
GROUP BY day_dt
ORDER BY day_dt
LIMIT 30;
