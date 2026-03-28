-- Лабораторная работа 8. Финальные демонстрационные запросы

-- 1) Наиболее загруженные рейсы
SELECT flight_id, flight_no, aircraft_code, total_people_onboard
FROM semester_ext.v_flight_load
ORDER BY total_people_onboard DESC
LIMIT 10;

-- 2) Топ маршрутов по начисленным милям
SELECT d.city ->> 'ru' AS from_city,
       a.city ->> 'ru' AS to_city,
       SUM(lo.miles) AS miles_earned
FROM semester_ext.loyalty_operations lo
JOIN flights f ON f.flight_id = lo.flight_id
JOIN airports_data d ON d.airport_code = f.departure_airport
JOIN airports_data a ON a.airport_code = f.arrival_airport
WHERE lo.operation_type = 'EARN'
GROUP BY from_city, to_city
ORDER BY miles_earned DESC
LIMIT 15;

-- 3) Пассажиры с частой сменой мест
SELECT t.passenger_name,
       COUNT(*) AS changes_cnt
FROM semester_ext.inflight_seat_changes sc
JOIN tickets t ON t.ticket_no = sc.ticket_no
JOIN flights f ON f.flight_id = sc.flight_id
GROUP BY t.passenger_name
HAVING COUNT(*) >= 2
ORDER BY changes_cnt DESC, t.passenger_name;
