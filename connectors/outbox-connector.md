
## DB 설정 값 정의
#### DB 설정 값 정의
(사용할 커넥터의 Java 클래스, 여기서는 PostgreSQL용 Debezium 커넥터를 사용)  
"connector.class": "io.debezium.connector.postgresql.PostgresConnector" 

(커넥터가 실행할 최대 작업 수, 보통 단일 DB 테이블 읽기에는 동시성 제어를 위해 1을 권장)  
"tasks.max": "1" 

(연결할 PostgreSQL 서버의 주소와 인증 정보, 논리적 복제 플러그인 설정)  
"database.hostname": "host.docker.internal"  
"database.port": "5432"  
"database.user": "koy"  
"database.dbname": "postgres"  
"plugin.name": "pgoutput"  

(변경 사항을 감시할 DB 테이블을 지정)  
"table.include.list": "public.kafka_outbox"  

(내부적으로 생성되는 메타데이터 토픽에 사용될, Kafka 토픽 이름의 접두사)
"topic.prefix": "emotiontree",  

(현재 커넥터에 'outbox'라는 이름의 변환 단계를 추가, 아래부터 transforms.outbox.xxx 식으로 사용)  
"transforms": "outbox",

(Debezium에서 제공하는 EventRouter 기능 사용 선언)  
"transforms.outbox.type": "io.debezium.transforms.outbox.EventRouter"  

(토픽 값을 가진 DB 컬럼명 정의 = public.kafka_outbox.topic)  
"transforms.outbox.route.by.field": "topic"  

(위에서 찾은 토픽 값을 최종적으로 토픽 값에 어떻게 사용할지 정의)  
"transforms.outbox.route.topic.replacement": "${routedByValue}"  

(Kafka 메시지의 본문이 될 데이터가 들어있는 DB 컬럼명 정의 = public.kafka_outbox.event_payload)  
"transforms.outbox.table.field.event.payload": "event_payload"  

(Kafka 메시지의 키가 될 데이터가 들어있는 DB 컬럼명 정의 = public.kafka_outbox.aggregate_id)  
"transforms.outbox.table.field.event.key": "aggregate_id"  

(Kafka 메세지의 순서를 보장할때 사용할 DB 칼럼 명 정의 = public.kafka_outbox.aggregate_id)  
"transforms.outbox.route.topic.partition.by": "aggregate_id"  

(DB의 추가 컬럼을 Kafka 메시지의 헤더에 넣고 싶을 때 사용)  
"transforms.outbox.table.fields.additional.placement": "event_type:header:eventType"

(DB에서 데이터가 삭제되었을 때 Kafka에 빈 메시지를 보낼지 말지를 결정)  
"tombstones.on.delete": "false"
