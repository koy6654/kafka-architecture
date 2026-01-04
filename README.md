# Kafka Architecture (with KRaft)

이벤트 중심의 MSA 아키텍처를 위한 Kafka 설계

(For OceansLab)

<br />

## 실행 방법

```
docker compose -f docker-compose.kraft.yml up -d
```

<br />

## 테스트 방법

```
./scripts/test.sh
```

<br />

## 유의 사항

**실제 서버에 적용할때 다음 옵션 값들을 고려해야함**

1. 브로커, 파티션 개수 관련 설정
   - KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR
   - KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR
   - KAFKA_TRANSACTION_STATE_LOG_MIN_ISR
   - KAFKA_MIN_INSYNC_REPLICAS
   - KAFKA_NUM_PARTITIONS
2. 토픽 제한
   - KAFKA_AUTO_CREATE_TOPICS_ENABLE
3. 브로커 메모리 설정
   - KAFKA_HEAP_OPTS
4. 호스트 및 도메인
   - KAFKA_LISTENERS
   - KAFKA_ADVERTISED_LISTENERS

<br />

## 아키텍처 구조 정의

- Broker: 3개
- Topic: 1개
- Partition: 3개 (Broker 수의 N배수 증가)
- Consumer Group: 2개 (MSA 구조의 서비스 개수)
- Consumer: 6개 (Consumer Group \* Partition)

<br />

## 그 외에 정리한 Kafka 지식들

[![Kafka Reference Image](/assets/kafka-reference-image.png)]()
<br> 출처: [Velog 기술 블로그](https://velog.io/@jwpark06/Kafka-%EC%8B%9C%EC%8A%A4%ED%85%9C-%EA%B5%AC%EC%A1%B0-%EC%95%8C%EC%95%84%EB%B3%B4%EA%B8%B0)

<br />

### Kafka 리더 종류

#### 브로커 리더 (Controller)

대상: 브로커(Broker) 중 한 대

역할: 클러스터의 '관리자'입니다.

설명: 모든 브로커 중 단 한 대만 선정됩니다. 브로커가 새로 추가되거나 죽었을 때 이를 감지하고, 아래 설명할 '파티션 리더'를 누구로 할지 결정하여 모든 브로커에게 지시하는 역할을 합니다. (KRaft 모드에서는 이 투표 과정이 매우 중요합니다.)

#### 파티션 리더 (Partition Leader)

대상: 특정 파티션의 복제본(Replica) 중 하나

역할: 실제 데이터의 '주인'입니다.

상세: 우리가 토픽에 메시지를 쓰고(Produce) 읽을(Consume) 때 직접 통신하는 대상입니다. 하나의 파티션이 여러 브로커에 복제되어 저장될 때, 그중 '리더'로 지정된 단 한 곳만이 쓰기/읽기 요청을 처리합니다. 나머지 복제본(Follower)은 리더의 데이터를 복사만 해둡니다.

#### 컨슈머 그룹 코디네이터 (Group Coordinator)

대상: 브로커 중 한 대

역할: 컨슈머 그룹의 '반장'입니다.

상세: 컨슈머 그룹 내의 컨슈머들이 살아있는지 체크(Heartbeat)하고, 어떤 컨슈머가 어떤 파티션을 읽을지 할당(Rebalancing)해주는 브로커입니다. 각 컨슈머 그룹마다 담당 코디네이터 브로커가 지정됩니다.

<br />

### Kafka Offset

#### 정의

파티션 내에 들어온 메시지에 부여되는 고유하고 순차적인 번호이자, 컨슈머가 어디까지 처리했는지 표시하는 책갈피

#### Kafka Offset 처리 순서

1. 새로운 데이터가 브로커에 들어옴
2. Offset 100번 부여
3. Log End Offset 101번으로 변경
4. 컨슈머가 Offset 100번을 Current Offset으로 부여하고 데이터를 가져옴
5. 컨슈머가 처리 완료 및 Commit 후 Committed Offset 101번 부여 (Committed Offset의 진짜 의미는 처리한 번호가 아니라, 여기서부터 다시 시작해라라는 시작점 좌표)

<br />

### Kafka 보안 프로토콜

- PLAINTEXT: 암호화 없는 평문 (우리가 쓰는 것)
- SSL: 암호화 통신
- SASL_PLAINTEXT: 아이디/비번 인증 + 평문
- SASL_SSL: 아이디/비번 인증 + 암호화

<br />

### Kafka의 트랜잭션 원리

#### 트랜잭션 생성

1. Producer가 Broker로 트랜잭션 ID 전송
2. Broker들은 Coordinator 선정 (Coordinator: 각 컨슈머 그룹의 브로커 리더)
3. Coordinator는 해당 Producer에게 Producer ID, Epoch(세대 번호)를 발급

#### 데이터 전송

1. Producer가 데이터를 보내기 시작하고, Coordinator는 자기 장부(\_\_transaction_state)에 현재 트랜잭션의 진행 중 상태, 토픽, 파티션 목록을 적어둠
2. Producer는 토픽에 메시지를 작성, Broker 디스크에 저장됨

#### 커밋 요청

1. Producer는 Coordinator에게 데이터 전송 완료 및 커밋 요청을 전달
2. Coordinator는 자기 장부의 트랜잭션 상태에 PREPARE_COMMIT로 상태 값 변경 (이제 트랜잭션은 성공한 것으로 간주됨 - 브로커가 죽어도 재부팅하면 여기서부터 이어서 가능, 마치 PSQL WAL LOG와 같음)

#### 커밋 마커 찍기

1. Coordinator가 적어둔 자기 장부에서 파티션 목록을 가져와 파티션 리더 Broker 에게 마커를 찍도록 요청
2. 각 파티션 리더는 데이터 맨 끝에 Commit Marker라는 특수한 메시지를 추가

#### 트랜잭션 종료 선언

1. Coordinator는 모든 파티션에 마커가 잘 박혔다는 보고를 받으면, 자기 장부에 최종적으로 COMPLETE_COMMIT을 기록
2. 이제 해당 트랜잭션 ID에 대한 상태 정보를 메모리에서 지우고 트랜잭션 종료
