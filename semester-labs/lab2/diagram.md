# Схема расширения (текстовое описание)

## Новые сущности
1. `semester_ext.employee_seat_occupancy`
2. `semester_ext.loyalty_accounts`
3. `semester_ext.loyalty_operations`
4. `semester_ext.inflight_seat_changes`

## Связи
1. `employee_seat_occupancy.flight_id -> flights.flight_id`
2. `loyalty_accounts.passenger_id` связан с `tickets.passenger_id` на уровне бизнес-логики.
3. `loyalty_operations.account_id -> loyalty_accounts.account_id`
4. `loyalty_operations.flight_id -> flights.flight_id`
5. `inflight_seat_changes.flight_id -> flights.flight_id`
6. `inflight_seat_changes.ticket_no -> tickets.ticket_no`

## Кардинальности
1. Один аккаунт лояльности -> много операций.
2. Один рейс -> много записей о сотрудниках и много смен мест.
3. Один билет -> много смен мест (если несколько пересадок внутри рейса не поддерживаются, можно ограничить до 1).
