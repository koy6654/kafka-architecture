-- Service A (주문) DB 및 Outbox 생성
CREATE DATABASE service_a_db;
\c service_a_db;

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    product_name VARCHAR(255),
    amount INT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE outbox (
    id UUID PRIMARY KEY,
    aggregate_type VARCHAR(255),
    aggregate_id VARCHAR(255),
    type VARCHAR(255),
    payload JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Service B (배송) DB 및 Outbox 생성
CREATE DATABASE service_b_db;
\c service_b_db;

CREATE TABLE deliveries (
    id SERIAL PRIMARY KEY,
    order_id INT,
    status VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE outbox (
    id UUID PRIMARY KEY,
    aggregate_type VARCHAR(255),
    aggregate_id VARCHAR(255),
    type VARCHAR(255),
    payload JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);