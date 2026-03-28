-- Лабораторная работа 2. Проектирование изменений схемы (выбран вариант 3: задания 5, 6, 7)
-- 5) Занятие места сотрудником без билета/посадочного талона
-- 6) Бонусная программа (начисление/списание миль)
-- 7) Регистрация смены места пассажира во время полета

-- Отдельная схема для семестровых расширений
CREATE SCHEMA IF NOT EXISTS semester_ext;

-- Задание 5: занятость места сотрудником без пассажирского билета
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

-- Задание 6: бонусная программа (счета + операции)
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

-- Задание 7: журнал смен мест в полете
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

-- Вспомогательные индексы
CREATE INDEX IF NOT EXISTS ix_emp_occ_flight ON semester_ext.employee_seat_occupancy(flight_id);
CREATE INDEX IF NOT EXISTS ix_loyalty_op_account_ts ON semester_ext.loyalty_operations(account_id, operation_ts DESC);
CREATE INDEX IF NOT EXISTS ix_seat_changes_flight_ts ON semester_ext.inflight_seat_changes(flight_id, changed_at DESC);
