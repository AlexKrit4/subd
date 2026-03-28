-- Лабораторная работа 3. Реализация изменений из ЛР2 (без потери данных)
BEGIN;

-- 1) Проверка существования схемы и таблиц (идемпотентность)
CREATE SCHEMA IF NOT EXISTS semester_ext;

CREATE TABLE IF NOT EXISTS semester_ext.employee_seat_occupancy (
    occupancy_id      BIGSERIAL PRIMARY KEY,
    flight_id         INTEGER NOT NULL REFERENCES flights(flight_id),
    employee_no       TEXT NOT NULL,
    employee_name     TEXT NOT NULL,
    seat_no           TEXT NOT NULL,
    role_code         TEXT NOT NULL,
    occupied_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    note              TEXT,
    UNIQUE (flight_id, seat_no),
    UNIQUE (flight_id, employee_no)
);

CREATE TABLE IF NOT EXISTS semester_ext.loyalty_accounts (
    account_id        BIGSERIAL PRIMARY KEY,
    passenger_id      TEXT NOT NULL UNIQUE,
    total_miles       INTEGER NOT NULL DEFAULT 0 CHECK (total_miles >= 0),
    level_name        TEXT NOT NULL DEFAULT 'Base',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS semester_ext.loyalty_operations (
    operation_id      BIGSERIAL PRIMARY KEY,
    account_id        BIGINT NOT NULL REFERENCES semester_ext.loyalty_accounts(account_id),
    operation_type    TEXT NOT NULL CHECK (operation_type IN ('EARN', 'SPEND', 'ADJUST')),
    miles             INTEGER NOT NULL CHECK (miles > 0),
    ticket_no         CHAR(13),
    flight_id         INTEGER REFERENCES flights(flight_id),
    operation_ts      TIMESTAMPTZ NOT NULL DEFAULT now(),
    description       TEXT
);

CREATE TABLE IF NOT EXISTS semester_ext.inflight_seat_changes (
    change_id         BIGSERIAL PRIMARY KEY,
    flight_id         INTEGER NOT NULL REFERENCES flights(flight_id),
    ticket_no         CHAR(13) NOT NULL REFERENCES tickets(ticket_no),
    old_seat_no       TEXT NOT NULL,
    new_seat_no       TEXT NOT NULL,
    changed_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    changed_by        TEXT NOT NULL,
    reason            TEXT,
    CHECK (old_seat_no <> new_seat_no)
);

CREATE INDEX IF NOT EXISTS ix_emp_occ_flight ON semester_ext.employee_seat_occupancy(flight_id);
CREATE INDEX IF NOT EXISTS ix_loyalty_op_account_ts ON semester_ext.loyalty_operations(account_id, operation_ts DESC);
CREATE INDEX IF NOT EXISTS ix_seat_changes_flight_ts ON semester_ext.inflight_seat_changes(flight_id, changed_at DESC);

-- 2) Миграция существующих пассажиров в счета лояльности
INSERT INTO semester_ext.loyalty_accounts (passenger_id, total_miles, level_name)
SELECT DISTINCT t.passenger_id,
       0,
       'Base'
FROM tickets t
LEFT JOIN semester_ext.loyalty_accounts la ON la.passenger_id = t.passenger_id
WHERE la.account_id IS NULL;

-- 3) Инициализация миль по историческим рейсам (упрощенная модель)
INSERT INTO semester_ext.loyalty_operations (account_id, operation_type, miles, ticket_no, flight_id, description)
SELECT la.account_id,
       'EARN',
       GREATEST(100, ROUND(f.actual_arrival - f.actual_departure))::INTEGER,
       tf.ticket_no,
       tf.flight_id,
       'Initial migration miles from completed flight'
FROM ticket_flights tf
JOIN tickets t ON t.ticket_no = tf.ticket_no
JOIN semester_ext.loyalty_accounts la ON la.passenger_id = t.passenger_id
JOIN flights f ON f.flight_id = tf.flight_id
LEFT JOIN semester_ext.loyalty_operations lo
       ON lo.ticket_no = tf.ticket_no
      AND lo.flight_id = tf.flight_id
      AND lo.operation_type = 'EARN'
WHERE f.status = 'Arrived'
  AND lo.operation_id IS NULL;

-- Пересчет балансов по журналу операций
UPDATE semester_ext.loyalty_accounts la
SET total_miles = x.balance,
    updated_at = now()
FROM (
    SELECT account_id,
           SUM(CASE operation_type
                   WHEN 'EARN' THEN miles
                   WHEN 'SPEND' THEN -miles
                   ELSE miles
               END)::INTEGER AS balance
    FROM semester_ext.loyalty_operations
    GROUP BY account_id
) x
WHERE x.account_id = la.account_id;

COMMIT;

-- Проверочные запросы
SELECT COUNT(*) AS loyalty_accounts_cnt FROM semester_ext.loyalty_accounts;
SELECT COUNT(*) AS loyalty_operations_cnt FROM semester_ext.loyalty_operations;
SELECT COUNT(*) AS seat_changes_cnt FROM semester_ext.inflight_seat_changes;
