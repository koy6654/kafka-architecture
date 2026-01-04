ALTER SYSTEM SET wal_level = logical;
ALTER ROLE koy WITH REPLICATION;
ALTER ROLE koy WITH LOGIN;

CREATE TABLE public.kafka_outbox (
    id UUID PRIMARY KEY,
    topic TEXT NOT NULL,                    -- 토픽 이름 결정
    aggregate_id TEXT NOT NULL,             -- 해당 데이터를 어느 파티션에 넣을지 결정하는 기준값이자, 동일한 ID를 가진 놈들을 한 줄로 세워 순서를 보장하는 파티션 키
    event_type TEXT NOT NULL,               -- 직접 넣는 이벤트 타입
    event_payload JSONB,                    -- 직접 넣는 이벤트 페이로드
    created_at TIMESTAMP DEFAULT NOW()
);

GRANT ALL PRIVILEGES ON DATABASE postgres TO koy;
GRANT ALL PRIVILEGES ON TABLE public.kafka_outbox TO postgres;
