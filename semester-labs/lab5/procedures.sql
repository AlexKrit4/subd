-- Лабораторная работа 5. Процедуры и триггеры
-- 1) Процедуры для изменений ЛР2 (задания 5,6,7)
-- 2) Процедура по ЛР5, вариант 3: замена самолета с проверкой проданных билетов

CREATE SCHEMA IF NOT EXISTS semester_ext;

-- Служебная функция: пересчет баланса миль по счету
CREATE OR REPLACE FUNCTION semester_ext.recalc_loyalty_balance(p_account_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE semester_ext.loyalty_accounts la
    SET total_miles = COALESCE(x.balance, 0),
        updated_at = now()
    FROM (
        SELECT account_id,
               SUM(CASE operation_type
                       WHEN 'EARN' THEN miles
                       WHEN 'SPEND' THEN -miles
                       ELSE miles
                   END)::INTEGER AS balance
        FROM semester_ext.loyalty_operations
        WHERE account_id = p_account_id
        GROUP BY account_id
    ) x
    WHERE la.account_id = x.account_id;
END;
$$;

-- Процедура A: назначение места сотруднику без билета
CREATE OR REPLACE PROCEDURE semester_ext.assign_employee_seat(
    p_flight_id INTEGER,
    p_employee_no TEXT,
    p_employee_name TEXT,
    p_seat_no TEXT,
    p_role_code TEXT,
    p_note TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_aircraft_code CHAR(3);
BEGIN
    SELECT aircraft_code INTO v_aircraft_code
    FROM flights
    WHERE flight_id = p_flight_id;

    IF v_aircraft_code IS NULL THEN
        RAISE EXCEPTION 'Flight % not found', p_flight_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM seats s
        WHERE s.aircraft_code = v_aircraft_code
          AND s.seat_no = p_seat_no
    ) THEN
        RAISE EXCEPTION 'Seat % does not exist in aircraft %', p_seat_no, v_aircraft_code;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM boarding_passes bp
        WHERE bp.flight_id = p_flight_id
          AND bp.seat_no = p_seat_no
    ) THEN
        RAISE EXCEPTION 'Seat % is already occupied by passenger', p_seat_no;
    END IF;

    INSERT INTO semester_ext.employee_seat_occupancy(
        flight_id, employee_no, employee_name, seat_no, role_code, note
    ) VALUES (
        p_flight_id, p_employee_no, p_employee_name, p_seat_no, p_role_code, p_note
    );
END;
$$;

-- Процедура B: регистрация смены места пассажира во время полета
CREATE OR REPLACE PROCEDURE semester_ext.register_inflight_seat_change(
    p_flight_id INTEGER,
    p_ticket_no CHAR(13),
    p_new_seat_no TEXT,
    p_changed_by TEXT,
    p_reason TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_old_seat_no TEXT;
    v_aircraft_code CHAR(3);
BEGIN
    SELECT bp.seat_no, f.aircraft_code
      INTO v_old_seat_no, v_aircraft_code
    FROM boarding_passes bp
    JOIN flights f ON f.flight_id = bp.flight_id
    WHERE bp.flight_id = p_flight_id
      AND bp.ticket_no = p_ticket_no;

    IF v_old_seat_no IS NULL THEN
        RAISE EXCEPTION 'Boarding pass not found for flight % and ticket %', p_flight_id, p_ticket_no;
    END IF;

    IF v_old_seat_no = p_new_seat_no THEN
        RAISE EXCEPTION 'New seat equals current seat';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM seats s
        WHERE s.aircraft_code = v_aircraft_code
          AND s.seat_no = p_new_seat_no
    ) THEN
        RAISE EXCEPTION 'Seat % does not exist in aircraft %', p_new_seat_no, v_aircraft_code;
    END IF;

    IF EXISTS (
        SELECT 1 FROM boarding_passes bp
        WHERE bp.flight_id = p_flight_id
          AND bp.seat_no = p_new_seat_no
    ) OR EXISTS (
        SELECT 1 FROM semester_ext.employee_seat_occupancy eo
        WHERE eo.flight_id = p_flight_id
          AND eo.seat_no = p_new_seat_no
    ) THEN
        RAISE EXCEPTION 'Seat % is already occupied', p_new_seat_no;
    END IF;

    UPDATE boarding_passes
    SET seat_no = p_new_seat_no
    WHERE flight_id = p_flight_id
      AND ticket_no = p_ticket_no;

    INSERT INTO semester_ext.inflight_seat_changes(
        flight_id, ticket_no, old_seat_no, new_seat_no, changed_by, reason
    ) VALUES (
        p_flight_id, p_ticket_no, v_old_seat_no, p_new_seat_no, p_changed_by, p_reason
    );
END;
$$;

-- Процедура C: ЛР5 вариант 3 - замена самолета с проверкой вместимости
CREATE OR REPLACE PROCEDURE semester_ext.replace_aircraft_with_check(
    p_flight_id INTEGER,
    p_new_aircraft_code CHAR(3)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sold_tickets INTEGER;
    v_new_capacity INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_sold_tickets
    FROM ticket_flights tf
    WHERE tf.flight_id = p_flight_id;

    SELECT COUNT(*) INTO v_new_capacity
    FROM seats s
    WHERE s.aircraft_code = p_new_aircraft_code;

    IF v_new_capacity IS NULL OR v_new_capacity = 0 THEN
        RAISE EXCEPTION 'New aircraft % has no seat configuration', p_new_aircraft_code;
    END IF;

    IF v_sold_tickets > v_new_capacity THEN
        RAISE EXCEPTION 'Cannot replace aircraft: sold tickets % > new capacity %', v_sold_tickets, v_new_capacity;
    END IF;

    UPDATE flights
    SET aircraft_code = p_new_aircraft_code
    WHERE flight_id = p_flight_id;
END;
$$;

-- Дополнительный триггер: автообновление баланса после операции лояльности
CREATE OR REPLACE FUNCTION semester_ext.trg_loyalty_recalc_fn()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM semester_ext.recalc_loyalty_balance(NEW.account_id);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_loyalty_recalc ON semester_ext.loyalty_operations;
CREATE TRIGGER trg_loyalty_recalc
AFTER INSERT OR UPDATE ON semester_ext.loyalty_operations
FOR EACH ROW
EXECUTE FUNCTION semester_ext.trg_loyalty_recalc_fn();

-- Примеры вызова (выполнять вручную с существующими ID):
-- CALL semester_ext.assign_employee_seat(100, 'EMP-01', 'Член экипажа', '1A', 'CABIN', 'Служебная посадка');
-- CALL semester_ext.register_inflight_seat_change(100, '0005432000987', '12C', 'бортпроводник', 'Запрос пассажира');
-- CALL semester_ext.replace_aircraft_with_check(100, '773');
