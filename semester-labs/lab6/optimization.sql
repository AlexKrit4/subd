-- Лабораторная работа 6. Оптимизация запросов
-- Цель: оптимизировать 3 запроса из ЛР1/ЛР4 и показать планы до/после.

-- Запрос A (ЛР1 #8): задержанные рейсы из Внуково по дате
EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_id, f.flight_no, f.scheduled_departure, f.actual_departure,
       (f.actual_departure - f.scheduled_departure) AS delay
FROM flights f
JOIN airports_data d ON d.airport_code = f.departure_airport
WHERE d.airport_name ->> 'ru' = 'Внуково'
  AND f.scheduled_departure::date = DATE '2025-10-01'
  AND f.actual_departure IS NOT NULL
  AND f.actual_departure - f.scheduled_departure > INTERVAL '2 hours';

CREATE INDEX IF NOT EXISTS ix_flights_departure_date_airport
    ON flights (departure_airport, scheduled_departure);

-- Переписанный вариант с диапазоном вместо приведения типа
EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_id, f.flight_no, f.scheduled_departure, f.actual_departure,
       (f.actual_departure - f.scheduled_departure) AS delay
FROM flights f
JOIN airports_data d ON d.airport_code = f.departure_airport
WHERE d.airport_name ->> 'ru' = 'Внуково'
  AND f.scheduled_departure >= TIMESTAMP '2025-10-01 00:00:00'
  AND f.scheduled_departure <  TIMESTAMP '2025-10-02 00:00:00'
  AND f.actual_departure IS NOT NULL
  AND f.actual_departure - f.scheduled_departure > INTERVAL '2 hours';


-- Запрос B (ЛР4 #2): мили по маршрутам
EXPLAIN (ANALYZE, BUFFERS)
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

CREATE INDEX IF NOT EXISTS ix_loyalty_operations_type_flight
    ON semester_ext.loyalty_operations(operation_type, flight_id);

CREATE INDEX IF NOT EXISTS ix_flights_route
    ON flights(departure_airport, arrival_airport);

EXPLAIN (ANALYZE, BUFFERS)
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


-- Запрос C (ЛР1 #3): пассажиры с максимальной стоимостью сегмента
EXPLAIN (ANALYZE, BUFFERS)
SELECT t.passenger_name, t.ticket_no, tf.amount
FROM ticket_flights tf
JOIN tickets t ON t.ticket_no = tf.ticket_no
WHERE tf.amount = (SELECT MAX(amount) FROM ticket_flights)
ORDER BY t.passenger_name;

CREATE INDEX IF NOT EXISTS ix_ticket_flights_amount_desc
    ON ticket_flights(amount DESC);

-- Переписанный вариант через ORDER BY/LIMIT для помощи планировщику
EXPLAIN (ANALYZE, BUFFERS)
WITH mx AS (
    SELECT amount
    FROM ticket_flights
    ORDER BY amount DESC
    LIMIT 1
)
SELECT t.passenger_name, t.ticket_no, tf.amount
FROM ticket_flights tf
JOIN tickets t ON t.ticket_no = tf.ticket_no
JOIN mx ON mx.amount = tf.amount
ORDER BY t.passenger_name;
