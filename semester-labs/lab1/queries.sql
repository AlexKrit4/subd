-- Лабораторная работа 1. PostgreSQL БД demo
-- Задания из lab1.txt (12 запросов)

-- 1) Список аэропортов, в которых побывал пассажир "Zhiming Hou"
WITH p AS (
    SELECT ticket_no
    FROM tickets
    WHERE passenger_name = 'Zhiming Hou'
), flights_of_passenger AS (
    SELECT DISTINCT f.departure_airport AS airport_code
    FROM ticket_flights tf
    JOIN flights f ON f.flight_id = tf.flight_id
    JOIN p ON p.ticket_no = tf.ticket_no
    UNION
    SELECT DISTINCT f.arrival_airport AS airport_code
    FROM ticket_flights tf
    JOIN flights f ON f.flight_id = tf.flight_id
    JOIN p ON p.ticket_no = tf.ticket_no
)
SELECT a.airport_code, a.airport_name ->> 'ru' AS airport_name_ru, a.city ->> 'ru' AS city_ru
FROM airports_data a
JOIN flights_of_passenger v ON v.airport_code = a.airport_code
ORDER BY city_ru, airport_name_ru;

-- 2) Самолеты с максимальным и минимальным числом мест
WITH seat_counts AS (
    SELECT s.aircraft_code, COUNT(*) AS seats_cnt
    FROM seats s
    GROUP BY s.aircraft_code
)
SELECT ad.aircraft_code, ad.model ->> 'ru' AS model_ru, sc.seats_cnt
FROM seat_counts sc
JOIN aircrafts_data ad ON ad.aircraft_code = sc.aircraft_code
WHERE sc.seats_cnt = (SELECT MAX(seats_cnt) FROM seat_counts)
   OR sc.seats_cnt = (SELECT MIN(seats_cnt) FROM seat_counts)
ORDER BY sc.seats_cnt DESC, ad.aircraft_code;

-- 3) Пассажиры с самым дорогим сегментом перелета
SELECT t.passenger_name, t.ticket_no, tf.amount
FROM ticket_flights tf
JOIN tickets t ON t.ticket_no = tf.ticket_no
WHERE tf.amount = (SELECT MAX(amount) FROM ticket_flights)
ORDER BY t.passenger_name;

-- 4) Свободные места на рейсе PG0035 на 2025-10-01
WITH target_flight AS (
    SELECT f.flight_id, f.aircraft_code
    FROM flights f
    WHERE f.flight_no = 'PG0035'
      AND f.scheduled_departure::date = DATE '2025-10-01'
), sold AS (
    SELECT COUNT(*) AS occupied
    FROM boarding_passes bp
    JOIN target_flight tf ON tf.flight_id = bp.flight_id
), capacity AS (
    SELECT COUNT(*) AS total_seats
    FROM seats s
    JOIN target_flight tf ON tf.aircraft_code = s.aircraft_code
)
SELECT c.total_seats - s.occupied AS free_seats
FROM capacity c
CROSS JOIN sold s;

-- 5) Аэропорт с максимальным числом принимаемых рейсов
WITH incoming AS (
    SELECT f.arrival_airport, COUNT(*) AS cnt
    FROM flights f
    GROUP BY f.arrival_airport
)
SELECT a.airport_code, a.airport_name ->> 'ru' AS airport_name_ru, i.cnt
FROM incoming i
JOIN airports_data a ON a.airport_code = i.arrival_airport
WHERE i.cnt = (SELECT MAX(cnt) FROM incoming);

-- 6) Китайские аэропорты южнее аэропорта Байсэ
WITH baise AS (
    SELECT coordinates[1] AS baise_lat
    FROM airports_data
    WHERE airport_name ->> 'ru' = 'Байсэ'
       OR airport_name ->> 'en' = 'Baise'
    LIMIT 1
)
SELECT a.airport_code, a.airport_name ->> 'en' AS airport_name_en, a.city ->> 'en' AS city_en
FROM airports_data a
CROSS JOIN baise b
WHERE a.timezone = 'Asia/Shanghai'
  AND a.coordinates[1] < b.baise_lat
ORDER BY a.coordinates[1];

-- 7) Можно ли улететь в среду из Шереметьево в Казань
SELECT EXISTS (
    SELECT 1
    FROM routes r
    JOIN airports_data d ON d.airport_code = r.departure_airport
    JOIN airports_data a ON a.airport_code = r.arrival_airport
    WHERE d.airport_name ->> 'ru' = 'Шереметьево'
      AND a.city ->> 'ru' = 'Казань'
      AND 3 = ANY(r.days_of_week)
) AS can_fly_wednesday;

-- 8) Рейсы из Внуково на 2025-10-01 с задержкой более 2 часов
SELECT f.flight_id, f.flight_no, f.scheduled_departure, f.actual_departure,
       (f.actual_departure - f.scheduled_departure) AS delay
FROM flights f
JOIN airports_data d ON d.airport_code = f.departure_airport
WHERE d.airport_name ->> 'ru' = 'Внуково'
  AND f.scheduled_departure::date = DATE '2025-10-01'
  AND f.actual_departure IS NOT NULL
  AND f.actual_departure - f.scheduled_departure > INTERVAL '2 hours'
ORDER BY delay DESC;

-- 9) Пассажиры с ровно 5 билетами и их маршруты
WITH p5 AS (
    SELECT t.passenger_id
    FROM tickets t
    GROUP BY t.passenger_id
    HAVING COUNT(DISTINCT t.ticket_no) = 5
)
SELECT t.passenger_name,
       STRING_AGG(DISTINCT (d.city ->> 'ru') || ' -> ' || (a.city ->> 'ru'), '; ') AS routes
FROM p5
JOIN tickets t ON t.passenger_id = p5.passenger_id
JOIN ticket_flights tf ON tf.ticket_no = t.ticket_no
JOIN flights f ON f.flight_id = tf.flight_id
JOIN airports_data d ON d.airport_code = f.departure_airport
JOIN airports_data a ON a.airport_code = f.arrival_airport
GROUP BY t.passenger_name
ORDER BY t.passenger_name;

-- 10) Рейсы Москва -> Санкт-Петербург и обратно по выходным
SELECT f.flight_id, f.flight_no,
       d.city ->> 'ru' AS from_city,
       a.city ->> 'ru' AS to_city,
       f.scheduled_departure
FROM flights f
JOIN airports_data d ON d.airport_code = f.departure_airport
JOIN airports_data a ON a.airport_code = f.arrival_airport
WHERE (
        (d.city ->> 'ru' = 'Москва' AND a.city ->> 'ru' IN ('Санкт-Петербург', 'С.-Петербург'))
     OR (d.city ->> 'ru' IN ('Санкт-Петербург', 'С.-Петербург') AND a.city ->> 'ru' = 'Москва')
      )
  AND EXTRACT(ISODOW FROM f.scheduled_departure) IN (6, 7)
ORDER BY f.scheduled_departure;

-- 11) Общее число часов в полете для "Lori Beasley" в октябре 2025
SELECT t.passenger_name,
       ROUND(EXTRACT(EPOCH FROM SUM(f.actual_arrival - f.actual_departure)) / 3600.0, 2) AS flight_hours
FROM tickets t
JOIN ticket_flights tf ON tf.ticket_no = t.ticket_no
JOIN flights f ON f.flight_id = tf.flight_id
WHERE t.passenger_name = 'Lori Beasley'
  AND f.actual_departure IS NOT NULL
  AND f.actual_arrival IS NOT NULL
  AND f.actual_departure >= TIMESTAMP '2025-10-01 00:00:00'
  AND f.actual_departure < TIMESTAMP '2025-11-01 00:00:00'
GROUP BY t.passenger_name;

-- 12) Количество пассажиров Москва -> Санкт-Петербург на 2025-10-09 с ценой < 4000
SELECT COUNT(DISTINCT t.passenger_id) AS passengers_cnt
FROM ticket_flights tf
JOIN tickets t ON t.ticket_no = tf.ticket_no
JOIN flights f ON f.flight_id = tf.flight_id
JOIN airports_data d ON d.airport_code = f.departure_airport
JOIN airports_data a ON a.airport_code = f.arrival_airport
WHERE d.city ->> 'ru' = 'Москва'
  AND a.city ->> 'ru' IN ('Санкт-Петербург', 'С.-Петербург')
  AND f.scheduled_departure::date = DATE '2025-10-09'
  AND tf.amount < 4000;
