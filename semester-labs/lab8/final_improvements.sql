-- Лабораторная работа 8. Финальная доработка структуры, запросов, процедур и приложения

BEGIN;

-- 1) Усиление контроля качества данных в новых таблицах
ALTER TABLE semester_ext.employee_seat_occupancy
    ADD CONSTRAINT ck_emp_role_code_nonempty CHECK (length(trim(role_code)) > 0);

ALTER TABLE semester_ext.inflight_seat_changes
    ADD CONSTRAINT ck_changed_by_nonempty CHECK (length(trim(changed_by)) > 0);

-- 2) Дополнительный индекс для быстрого поиска по билету в истории смен мест
CREATE INDEX IF NOT EXISTS ix_seat_changes_ticket_ts
    ON semester_ext.inflight_seat_changes(ticket_no, changed_at DESC);

-- 3) Аналитическое представление для быстрой сводки
CREATE OR REPLACE VIEW semester_ext.v_flight_load AS
SELECT f.flight_id,
       f.flight_no,
       f.aircraft_code,
       COUNT(DISTINCT bp.ticket_no) AS boarded_passengers,
       COUNT(DISTINCT eo.employee_no) AS onboard_employees,
       COUNT(DISTINCT bp.ticket_no) + COUNT(DISTINCT eo.employee_no) AS total_people_onboard
FROM flights f
LEFT JOIN boarding_passes bp ON bp.flight_id = f.flight_id
LEFT JOIN semester_ext.employee_seat_occupancy eo ON eo.flight_id = f.flight_id
GROUP BY f.flight_id, f.flight_no, f.aircraft_code;

COMMIT;

-- Демонстрационный вывод
SELECT *
FROM semester_ext.v_flight_load
ORDER BY total_people_onboard DESC
LIMIT 20;
