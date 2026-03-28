#!/usr/bin/env python3
import os
import sys
from dataclasses import dataclass

import psycopg


@dataclass
class DbConfig:
    host: str
    port: int
    dbname: str
    user: str
    password: str


def load_config() -> DbConfig:
    return DbConfig(
        host=os.getenv("PGHOST", "localhost"),
        port=int(os.getenv("PGPORT", "5432")),
        dbname=os.getenv("PGDATABASE", "demo"),
        user=os.getenv("PGUSER", "postgres"),
        password=os.getenv("PGPASSWORD", "postgres"),
    )


def connect(cfg: DbConfig):
    return psycopg.connect(
        host=cfg.host,
        port=cfg.port,
        dbname=cfg.dbname,
        user=cfg.user,
        password=cfg.password,
    )


def call_assign_employee_seat(conn):
    flight_id = int(input("flight_id: ").strip())
    employee_no = input("employee_no: ").strip()
    employee_name = input("employee_name: ").strip()
    seat_no = input("seat_no: ").strip()
    role_code = input("role_code: ").strip()
    note = input("note (optional): ").strip() or None

    with conn.cursor() as cur:
        cur.execute(
            "CALL semester_ext.assign_employee_seat(%s,%s,%s,%s,%s,%s)",
            (flight_id, employee_no, employee_name, seat_no, role_code, note),
        )
    conn.commit()
    print("Done: employee seat assigned")


def call_register_seat_change(conn):
    flight_id = int(input("flight_id: ").strip())
    ticket_no = input("ticket_no: ").strip()
    new_seat_no = input("new_seat_no: ").strip()
    changed_by = input("changed_by: ").strip()
    reason = input("reason (optional): ").strip() or None

    with conn.cursor() as cur:
        cur.execute(
            "CALL semester_ext.register_inflight_seat_change(%s,%s,%s,%s,%s)",
            (flight_id, ticket_no, new_seat_no, changed_by, reason),
        )
    conn.commit()
    print("Done: seat changed and logged")


def call_replace_aircraft(conn):
    flight_id = int(input("flight_id: ").strip())
    new_aircraft_code = input("new_aircraft_code: ").strip()

    with conn.cursor() as cur:
        cur.execute(
            "CALL semester_ext.replace_aircraft_with_check(%s,%s)",
            (flight_id, new_aircraft_code),
        )
    conn.commit()
    print("Done: aircraft replaced")


def show_menu():
    print("\n=== Semester DB App (Lab7) ===")
    print("1. Assign employee seat")
    print("2. Register in-flight seat change")
    print("3. Replace aircraft with sold-ticket check")
    print("4. Exit")


def main():
    cfg = load_config()
    try:
        conn = connect(cfg)
    except Exception as exc:
        print(f"DB connection error: {exc}")
        sys.exit(1)

    try:
        while True:
            show_menu()
            choice = input("Select: ").strip()
            try:
                if choice == "1":
                    call_assign_employee_seat(conn)
                elif choice == "2":
                    call_register_seat_change(conn)
                elif choice == "3":
                    call_replace_aircraft(conn)
                elif choice == "4":
                    break
                else:
                    print("Unknown option")
            except Exception as exc:
                conn.rollback()
                print(f"Operation failed: {exc}")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
