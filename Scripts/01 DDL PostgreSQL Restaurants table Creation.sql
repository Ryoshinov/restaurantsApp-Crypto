-- ============================================================
-- RESTAURANT PLATFORM - MOTHER MODEL v1
-- PostgreSQL with TimeSTAMPTZ
-- 
-- ============================================================


-- ============================================================
-- 1. RESTAURANT
-- ============================================================

CREATE TABLE restaurant (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    legal_name      VARCHAR(200),
    address         VARCHAR(500),
    phone           VARCHAR(50),
    email           VARCHAR(255),

    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- 2. FLOOR
-- ============================================================

CREATE TABLE floor (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    restaurant_id   BIGINT NOT NULL,

    name            VARCHAR(100) NOT NULL,
    width           NUMERIC(10,2),
    height          NUMERIC(10,2),

    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_floor_restaurant
        FOREIGN KEY (restaurant_id)
        REFERENCES restaurant(id)
        ON DELETE CASCADE,

    CONSTRAINT uq_floor_restaurant_name
        UNIQUE (restaurant_id, name)
);


-- ============================================================
-- 3. RESTAURANT TABLE
-- ============================================================

CREATE TABLE restaurant_table (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    restaurant_id   BIGINT NOT NULL,
    floor_id        BIGINT NOT NULL,

    table_number    INTEGER NOT NULL,
    capacity        INTEGER NOT NULL,

    shape           VARCHAR(30),

    position_x      NUMERIC(10,2),
    position_y      NUMERIC(10,2),
    width           NUMERIC(10,2),
    height          NUMERIC(10,2),
    rotation        NUMERIC(6,2),

    status          VARCHAR(30) NOT NULL DEFAULT 'AVAILABLE',

    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_table_restaurant
        FOREIGN KEY (restaurant_id)
        REFERENCES restaurant(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_table_floor
        FOREIGN KEY (floor_id)
        REFERENCES floor(id)
        ON DELETE CASCADE,

    CONSTRAINT uq_table_restaurant_number
        UNIQUE (restaurant_id, table_number),

    CONSTRAINT chk_table_capacity
        CHECK (capacity > 0),

    CONSTRAINT chk_table_status
        CHECK (status IN (
            'AVAILABLE',
            'RESERVED',
            'OCCUPIED',
            'BILLING',
            'OUT_OF_SERVICE'
        ))
);


-- ============================================================
-- 4. TABLE SEAT
-- ============================================================

CREATE TABLE table_seat (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_id        BIGINT NOT NULL,

    seat_number     INTEGER NOT NULL,

    position_x      NUMERIC(10,2),
    position_y      NUMERIC(10,2),
    rotation        NUMERIC(6,2),

    CONSTRAINT fk_seat_table
        FOREIGN KEY (table_id)
        REFERENCES restaurant_table(id)
        ON DELETE CASCADE,

    CONSTRAINT uq_table_seat_number
        UNIQUE (table_id, seat_number),

    CONSTRAINT chk_seat_number
        CHECK (seat_number > 0)
);


-- ============================================================
-- 5. ROLE
-- ============================================================

CREATE TABLE role (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    restaurant_id   BIGINT NOT NULL,

    name            VARCHAR(100) NOT NULL,

    CONSTRAINT fk_role_restaurant
        FOREIGN KEY (restaurant_id)
        REFERENCES restaurant(id)
        ON DELETE CASCADE,

    CONSTRAINT uq_role_restaurant_name
        UNIQUE (restaurant_id, name)
);


-- ============================================================
-- 6. EMPLOYEE
-- ============================================================

CREATE TABLE employee (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    restaurant_id   BIGINT NOT NULL,
    role_id         BIGINT,

    first_name      VARCHAR(100) NOT NULL,
    last_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(255),
    phone           VARCHAR(50),

    active          BOOLEAN NOT NULL DEFAULT TRUE,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_employee_restaurant
        FOREIGN KEY (restaurant_id)
        REFERENCES restaurant(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_employee_role
        FOREIGN KEY (role_id)
        REFERENCES role(id)
        ON DELETE SET NULL
);


-- ============================================================
-- 7. MENU CATEGORY
-- ============================================================

CREATE TABLE menu_category (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    restaurant_id   BIGINT NOT NULL,

    name            VARCHAR(150) NOT NULL,
    description     TEXT,

    display_order   INTEGER NOT NULL DEFAULT 0,
    active          BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_menu_category_restaurant
        FOREIGN KEY (restaurant_id)
        REFERENCES restaurant(id)
        ON DELETE CASCADE,

    CONSTRAINT uq_menu_category_restaurant_name
        UNIQUE (restaurant_id, name)
);


-- ============================================================
-- 8. MENU ITEM
-- ============================================================

CREATE TABLE menu_item (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    restaurant_id   BIGINT NOT NULL,
    category_id     BIGINT NOT NULL,

    name            VARCHAR(200) NOT NULL,
    description     TEXT,

    price           NUMERIC(12,2) NOT NULL,
	discounted_price numeric (12, 2), -- not null ?
    active          BOOLEAN NOT NULL DEFAULT TRUE,
    -- discount_active     BOOLEAN NOT NULL DEFAULT FALSE, -- discount is active flag

    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_menu_item_restaurant
        FOREIGN KEY (restaurant_id)
        REFERENCES restaurant(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_menu_item_category
        FOREIGN KEY (category_id)
        REFERENCES menu_category(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_menu_item_price
        CHECK (price >= 0),
       CONSTRAINT chk_menu_item_discount
        CHECK (
            discounted_price IS NULL
            OR discounted_price > 0
        ),

    CONSTRAINT chk_menu_item_discount_lower
        CHECK (
            discounted_price IS NULL
            OR discounted_price < price
        ) --,
       -- CONSTRAINT chk_discount_active_requires_price
    	--- CHECK (
        -- discount_active = FALSE
        -- OR discounted_price IS NOT NULL
   --  )
);

alter table menu_item add column discount_active BOOLEAN not null default false;

alter table menu_item add constraint chk_discount_active_requires_price check (discount_active = false or discounted_price is not NULL);

-- ============================================================
-- 9. RESERVATION
-- ============================================================

CREATE TABLE reservation (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    restaurant_id   BIGINT NOT NULL,

    customer_name   VARCHAR(200) NOT NULL,
    customer_phone  VARCHAR(50),
    customer_email  VARCHAR(255),

    party_size      INTEGER NOT NULL,

    start_time      TIMESTAMPTZ NOT NULL,
    end_time        TIMESTAMPTZ,

    status          VARCHAR(30) NOT NULL DEFAULT 'PENDING',

    confirmed_at    TIMESTAMPTZ,
    arrived_at      TIMESTAMPTZ,
    seated_at       TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,
    cancelled_at    TIMESTAMPTZ,

    notes           TEXT,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_reservation_restaurant
        FOREIGN KEY (restaurant_id)
        REFERENCES restaurant(id)
        ON DELETE CASCADE,

    CONSTRAINT chk_reservation_party_size
        CHECK (party_size > 0),

    CONSTRAINT chk_reservation_time
        CHECK (
            end_time IS NULL
            OR end_time > start_time
        ),

    CONSTRAINT chk_reservation_status
        CHECK (status IN (
            'PENDING',
            'CONFIRMED',
            'CANCELLED',
            'NO_SHOW',
            'ARRIVED',
            'SEATED',
            'COMPLETED'
        ))
);


-- ============================================================
-- 10. RESERVATION TABLE
-- ============================================================

CREATE TABLE reservation_table (
    reservation_id  BIGINT NOT NULL,
    table_id        BIGINT NOT NULL,

    PRIMARY KEY (reservation_id, table_id),

    CONSTRAINT fk_reservation_table_reservation
        FOREIGN KEY (reservation_id)
        REFERENCES reservation(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_reservation_table_table
        FOREIGN KEY (table_id)
        REFERENCES restaurant_table(id)
        ON DELETE CASCADE
);


-- ============================================================
-- 11. DINING SESSION
-- ============================================================

CREATE TABLE dining_session (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    restaurant_id       BIGINT NOT NULL,
    reservation_id      BIGINT,

    guest_count         INTEGER NOT NULL,

    started_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at            TIMESTAMPTZ,

    status              VARCHAR(30) NOT NULL DEFAULT 'OPEN',

    CONSTRAINT fk_dining_session_restaurant
        FOREIGN KEY (restaurant_id)
        REFERENCES restaurant(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_dining_session_reservation
        FOREIGN KEY (reservation_id)
        REFERENCES reservation(id)
        ON DELETE SET NULL,

    CONSTRAINT chk_dining_session_guest_count
        CHECK (guest_count > 0),

    CONSTRAINT chk_dining_session_time
        CHECK (
            ended_at IS NULL
            OR ended_at >= started_at
        ),

    CONSTRAINT chk_dining_session_status
        CHECK (status IN (
            'OPEN',
            'CLOSED',
            'CANCELLED'
        ))
);


-- ============================================================
-- 12. DINING SESSION TABLE
-- ============================================================

CREATE TABLE dining_session_table (
    dining_session_id   BIGINT NOT NULL,
    table_id            BIGINT NOT NULL,

    PRIMARY KEY (dining_session_id, table_id),

    CONSTRAINT fk_session_table_session
        FOREIGN KEY (dining_session_id)
        REFERENCES dining_session(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_session_table_table
        FOREIGN KEY (table_id)
        REFERENCES restaurant_table(id)
        ON DELETE CASCADE
);


-- ============================================================
-- 13. RESTAURANT ORDER
-- ============================================================

CREATE TABLE restaurant_order (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    restaurant_id       BIGINT NOT NULL,
    dining_session_id   BIGINT NOT NULL,
    employee_id         BIGINT,

    status              VARCHAR(30) NOT NULL DEFAULT 'OPEN',

    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    submitted_at        TIMESTAMPTZ,
    preparing_at        TIMESTAMPTZ,
    ready_at            TIMESTAMPTZ,
    served_at           TIMESTAMPTZ,
    cancelled_at        TIMESTAMPTZ,

    updated_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_order_restaurant
        FOREIGN KEY (restaurant_id)
        REFERENCES restaurant(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_order_dining_session
        FOREIGN KEY (dining_session_id)
        REFERENCES dining_session(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_order_employee
        FOREIGN KEY (employee_id)
        REFERENCES employee(id)
        ON DELETE SET NULL,

    CONSTRAINT chk_order_status
        CHECK (status IN (
            'OPEN',
            'SUBMITTED',
            'PREPARING',
            'READY',
            'SERVED',
            'CANCELLED'
        ))
);


-- ============================================================
-- 14. ORDER ITEM
-- ============================================================

CREATE TABLE order_item (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    order_id        BIGINT NOT NULL,
    menu_item_id    BIGINT NOT NULL,

    quantity        INTEGER NOT NULL,
    unit_price      NUMERIC(12,2) NOT NULL,

    status          VARCHAR(30) NOT NULL DEFAULT 'OPEN',

    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_order_item_order
        FOREIGN KEY (order_id)
        REFERENCES restaurant_order(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_order_item_menu_item
        FOREIGN KEY (menu_item_id)
        REFERENCES menu_item(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_order_item_quantity
        CHECK (quantity > 0),

    CONSTRAINT chk_order_item_price
        CHECK (unit_price >= 0),

    CONSTRAINT chk_order_item_status
        CHECK (status IN (
            'OPEN',
            'SUBMITTED',
            'PREPARING',
            'READY',
            'SERVED',
            'CANCELLED'
        ))
);


-- ============================================================
-- 15. RESTAURANT CHECK
-- ============================================================
-- Represents the bill/check for a dining session.
-- A dining session can have multiple checks.
-- This is what allows split billing.
-- ============================================================

CREATE TABLE restaurant_check (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    restaurant_id       BIGINT NOT NULL,
    dining_session_id   BIGINT NOT NULL,

    status              VARCHAR(30) NOT NULL DEFAULT 'OPEN',

    total_amount        NUMERIC(12,2) NOT NULL DEFAULT 0,

    opened_at           TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    closed_at           TIMESTAMPTZ,

    CONSTRAINT fk_check_restaurant
        FOREIGN KEY (restaurant_id)
        REFERENCES restaurant(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_check_dining_session
        FOREIGN KEY (dining_session_id)
        REFERENCES dining_session(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_check_total
        CHECK (total_amount >= 0),

    CONSTRAINT chk_check_status
        CHECK (status IN (
            'OPEN',
            'PARTIALLY_PAID',
            'PAID',
            'CANCELLED'
        )),

    CONSTRAINT chk_check_time
        CHECK (
            closed_at IS NULL
            OR closed_at >= opened_at
        )
);


-- ============================================================
-- 16. PAYMENT
-- ============================================================

CREATE TABLE payment (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    check_id        BIGINT NOT NULL,

    amount          NUMERIC(12,2) NOT NULL,

    payment_method  VARCHAR(30) NOT NULL,
    status          VARCHAR(30) NOT NULL DEFAULT 'INITIATED',

    initiated_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at    TIMESTAMPTZ,
    failed_at       TIMESTAMPTZ,
    refunded_at     TIMESTAMPTZ,

    CONSTRAINT fk_payment_check
        FOREIGN KEY (check_id)
        REFERENCES restaurant_check(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_payment_amount
        CHECK (amount > 0),

    CONSTRAINT chk_payment_method
        CHECK (payment_method IN (
            'CASH',
            'CARD',
            'BANK_TRANSFER',
            'OTHER'
        )),

    CONSTRAINT chk_payment_status
        CHECK (status IN (
            'INITIATED',
            'PROCESSING',
            'COMPLETED',
            'FAILED',
            'REFUNDED',
            'CANCELLED'
        ))
);