-- Вариант 3. Учет приватизации жилья
-- SQL-диалект: PostgreSQL

-- =====================================================
-- A) ОДНА ТАБЛИЦА СО ВСЕМИ АТРИБУТАМИ
-- =====================================================
DROP TABLE IF EXISTS privatization_all;

CREATE TABLE privatization_all (
    address             VARCHAR(60)  NOT NULL, -- Address
    district            VARCHAR(15)  NOT NULL, -- District
    balance             VARCHAR(60)  NOT NULL, -- Balance
    year_built          INTEGER      NOT NULL CHECK (year_built BETWEEN 1800 AND 2100), -- Year
    material            VARCHAR(15)  NOT NULL, -- Material
    base_material       VARCHAR(15)  NOT NULL, -- Base
    wear_percent        INTEGER      NOT NULL CHECK (wear_percent BETWEEN 0 AND 100), -- Wear
    flow_count          INTEGER      NOT NULL CHECK (flow_count > 0), -- Flow
    line_distance       INTEGER      NOT NULL CHECK (line_distance >= 0), -- Line
    square_total        NUMERIC(10,2) NOT NULL CHECK (square_total >= 0), -- Square
    hall                BOOLEAN      NOT NULL, -- Hall
    flats_count         INTEGER      NOT NULL CHECK (flats_count > 0), -- Flats
    elevator            BOOLEAN      NOT NULL, -- Elevator

    flat_no             INTEGER      NOT NULL CHECK (flat_no > 0), -- Flat
    storey              INTEGER      NOT NULL CHECK (storey > 0), -- Storey
    rooms               INTEGER      NOT NULL CHECK (rooms > 0), -- Rooms
    square_flat         NUMERIC(10,2) NOT NULL CHECK (square_flat >= 0), -- SquareFlat
    dwell               NUMERIC(10,2) NOT NULL CHECK (dwell >= 0), -- Dwell
    branch              NUMERIC(10,2) NOT NULL CHECK (branch >= 0), -- Branch
    balcony             NUMERIC(10,2) NOT NULL CHECK (balcony >= 0), -- Balcony
    height              NUMERIC(4,2)  NOT NULL CHECK (height > 0), -- Height

    record_no           INTEGER, -- Record
    document            VARCHAR(60), -- Document
    date_doc            DATE, -- DateDoc
    cost                NUMERIC(14,2), -- Cost

    fio_host            VARCHAR(60)  NOT NULL, -- FioHost
    passport            VARCHAR(60)  NOT NULL, -- Pasport
    sign_participation  BOOLEAN      NOT NULL, -- Sign
    born_year           INTEGER      NOT NULL CHECK (born_year BETWEEN 1900 AND 2100), -- Born
    family_status       VARCHAR(20)  NOT NULL, -- Status

    -- Для одной "плоской" таблицы берем составной ключ на уровне "человек в квартире"
    PRIMARY KEY (address, district, flat_no, passport)
);


-- =====================================================
-- B) НЕСКОЛЬКО ВЗАИМОСВЯЗАННЫХ ТАБЛИЦ (НОРМАЛИЗОВАННАЯ СХЕМА)
-- 1) buildings
-- 2) flats
-- 3) privatizations
-- 4) residents
-- =====================================================
DROP TABLE IF EXISTS residents;
DROP TABLE IF EXISTS privatizations;
DROP TABLE IF EXISTS flats;
DROP TABLE IF EXISTS buildings;

-- 1) Здания: составной PK, т.к. уникального кадастрового номера нет
CREATE TABLE buildings (
    address             VARCHAR(60)  NOT NULL,
    district            VARCHAR(15)  NOT NULL,
    balance             VARCHAR(60)  NOT NULL,
    year_built          INTEGER      NOT NULL CHECK (year_built BETWEEN 1800 AND 2100),
    material            VARCHAR(15)  NOT NULL,
    base_material       VARCHAR(15)  NOT NULL,
    wear_percent        INTEGER      NOT NULL CHECK (wear_percent BETWEEN 0 AND 100),
    flow_count          INTEGER      NOT NULL CHECK (flow_count > 0),
    line_distance       INTEGER      NOT NULL CHECK (line_distance >= 0),
    square_total        NUMERIC(10,2) NOT NULL CHECK (square_total >= 0),
    hall                BOOLEAN      NOT NULL,
    flats_count         INTEGER      NOT NULL CHECK (flats_count > 0),
    elevator            BOOLEAN      NOT NULL,
    PRIMARY KEY (address, district)
);

-- 2) Квартиры: составной PK (здание + номер квартиры)
CREATE TABLE flats (
    address             VARCHAR(60)  NOT NULL,
    district            VARCHAR(15)  NOT NULL,
    flat_no             INTEGER      NOT NULL CHECK (flat_no > 0),
    storey              INTEGER      NOT NULL CHECK (storey > 0),
    rooms               INTEGER      NOT NULL CHECK (rooms > 0),
    square_flat         NUMERIC(10,2) NOT NULL CHECK (square_flat >= 0),
    dwell               NUMERIC(10,2) NOT NULL CHECK (dwell >= 0),
    branch              NUMERIC(10,2) NOT NULL CHECK (branch >= 0),
    balcony             NUMERIC(10,2) NOT NULL CHECK (balcony >= 0),
    height              NUMERIC(4,2)  NOT NULL CHECK (height > 0),
    PRIMARY KEY (address, district, flat_no),
    FOREIGN KEY (address, district)
        REFERENCES buildings(address, district)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- 3) Данные по приватизации квартиры
CREATE TABLE privatizations (
    address             VARCHAR(60)  NOT NULL,
    district            VARCHAR(15)  NOT NULL,
    flat_no             INTEGER      NOT NULL,
    record_no           INTEGER      NOT NULL CHECK (record_no > 0),
    document            VARCHAR(60)  NOT NULL,
    date_doc            DATE         NOT NULL,
    cost                NUMERIC(14,2) NOT NULL CHECK (cost >= 0),
    PRIMARY KEY (address, district, flat_no, record_no),
    FOREIGN KEY (address, district, flat_no)
        REFERENCES flats(address, district, flat_no)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- 4) Проживающие: составной PK (квартира + паспорт)
CREATE TABLE residents (
    address             VARCHAR(60)  NOT NULL,
    district            VARCHAR(15)  NOT NULL,
    flat_no             INTEGER      NOT NULL,
    fio_host            VARCHAR(60)  NOT NULL,
    passport            VARCHAR(60)  NOT NULL,
    sign_participation  BOOLEAN      NOT NULL,
    born_year           INTEGER      NOT NULL CHECK (born_year BETWEEN 1900 AND 2100),
    family_status       VARCHAR(20)  NOT NULL,
    PRIMARY KEY (address, district, flat_no, passport),
    FOREIGN KEY (address, district, flat_no)
        REFERENCES flats(address, district, flat_no)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- Ключевое ограничение варианта:
-- один и тот же человек (passport) не может участвовать в приватизации более одной квартиры.
-- Разрешаем повторяться в разных квартирах только если sign_participation = false.
CREATE UNIQUE INDEX uq_resident_one_privatisation
    ON residents(passport)
    WHERE sign_participation = true;

-- Дополнительно: в рамках квартиры не более одного участника со статусом "главный"
-- (это не требование задания, а пример бизнес-ограничения при необходимости)
-- CREATE UNIQUE INDEX uq_one_head_per_flat
--     ON residents(address, district, flat_no)
--     WHERE family_status = 'Главный';
