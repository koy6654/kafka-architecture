#!/bin/bash

# ------------------------------------------------------------
# 변수 설정 (나중에 토픽명이나 브로커 주소가 바뀌면 여기만 수정)
# ------------------------------------------------------------
BOOTSTRAP_SERVER="kafka-broker-1:29092"
TARGET_TOPIC="cluster-test-topic"
CONSUMER_BROKER="kafka-broker-3:29092" # 소비 확인할 다른 브로커

echo "===== 토픽 생성 및 메세지 발송 테스트 시작 ====="
sleep 3

# 1. [토픽 생성] 3개 브로커에 3중 복제되는 토픽 생성
echo "--- 1. 토픽 생성 (3 Partitions, 3 Replicas) ---"
docker exec -it kafka-broker-1 kafka-topics --create \
  --bootstrap-server $BOOTSTRAP_SERVER \
  --topic $TARGET_TOPIC \
  --partitions 3 \
  --replication-factor 3

# 2. [상태 확인] 파티션 리더와 동기화 상태(ISR) 진단
echo -e "\n\n--- 2. 토픽 상세 상태(Describe) 진단 ---"
docker exec -it kafka-broker-1 kafka-topics --describe \
  --bootstrap-server $BOOTSTRAP_SERVER \
  --topic $TARGET_TOPIC
# Tip: Leader가 1, 2, 3으로 골고루 분산되어야 건강한 클러스터입니다.

# 3. [메시지 발행] 1번 브로커를 통해 메시지 3개 전송
echo -e "\n\n--- 3. 메시지 발행 테스트 (Producer) ---"
echo -e "Message-1\nMessage-2\nMessage-3" | docker exec -i kafka-broker-1 kafka-console-producer \
  --bootstrap-server $BOOTSTRAP_SERVER \
  --topic $TARGET_TOPIC
echo "전송 완료!"

# 4. [메시지 소비] 다른 브로커(3번)를 통해 데이터 복제 완료 확인
echo -e "\n\n--- 4. 메시지 복제 확인 (Consumer & Broker 3) ---"
docker exec -it kafka-broker-3 kafka-console-consumer \
  --bootstrap-server $CONSUMER_BROKER \
  --topic $TARGET_TOPIC \
  --from-beginning --max-messages 3

# 5. [테스트 종료 및 청소] 사용한 테스트 토픽 삭제
echo -e "\n\n--- 5. 테스트 종료 및 리소스 청소 (Topic Delete) ---"
docker exec -it kafka-broker-1 kafka-topics --delete \
  --bootstrap-server $BOOTSTRAP_SERVER \
  --topic $TARGET_TOPIC
echo "청소 완료!"

echo -e "\n\n\n"

echo "===== 브로커 장애 발생 시 CONTROLLER 변환 테스트 시작 ====="
BOOTSTRAP_SERVER="kafka-broker-1:29092"
TARGET_TOPIC="failover-test-topic"
BACKUP_SERVER="kafka-broker-2:29092"

echo "--- 1. 테스트 토픽 생성 (3 Replicas) ---"
docker exec -it kafka-broker-1 kafka-topics --create \
  --bootstrap-server $BOOTSTRAP_SERVER \
  --topic $TARGET_TOPIC \
  --partitions 1 \
  --replication-factor 3

echo -e "\n\n--- 2. [정상 상태] 현재 리더 브로커 확인 ---"
# tr -d '\r'를 추가하여 변수에 들어가는 개행 문자를 제거했습니다.
LEADER_ID=$(docker exec -it kafka-broker-1 kafka-topics --describe --bootstrap-server $BOOTSTRAP_SERVER --topic $TARGET_TOPIC | grep "Partition: 0" | awk '{print $6}' | tr -d '\r')
LEADER_BROKER="kafka-broker-$LEADER_ID"
docker exec -it kafka-broker-1 kafka-topics --describe --bootstrap-server $BOOTSTRAP_SERVER --topic $TARGET_TOPIC

# 리더가 1번일 경우 명령을 내릴 백업 브로커를 선정합니다.
if [ "$LEADER_ID" == "1" ]; then SURVIVOR="kafka-broker-2"; else SURVIVOR="kafka-broker-1"; fi

echo -e "\n\n--- 3. [장애 발생] 브로커 리더 강제 중지 ---"
# 실제 추출된 리더인 $LEADER_BROKER를 중지합니다.
docker stop "$LEADER_BROKER"
echo "Broker $LEADER_BROKER is down."

echo -e "\n\n--- 4. [장애 복구] 각 브로커 상태 확인 & 리더가 바뀌었는지 확인 ---"
sleep 5
# 죽은 브로커에 docker exec를 시도하면 에러가 나므로, 살아있는 $SURVIVOR를 사용합니다.
echo "브로커 리더 죽은 것 확인 $LEADER_BROKER..."
docker exec -it $LEADER_BROKER kafka-topics --describe --bootstrap-server $LEADER_BROKER:29092 --topic $TARGET_TOPIC
sleep 3
echo "&"
echo "살아있는 브로커 및 리더 바뀌었는지 확인 $SURVIVOR..."
docker exec -it $SURVIVOR kafka-topics --describe --bootstrap-server $SURVIVOR:29092 --topic $TARGET_TOPIC

echo -e "\n\n--- 5. [복구 시도] 강제 중지했던 예전 브로커 리더 살리기 ---"
docker start "$LEADER_BROKER"
echo "Broker $LEADER_BROKER is starting..."

echo -e "\n\n--- 6. [복구 확인] ISR에 예전 브로커 리더가 다시 들어왔는지 확인 ---"
sleep 10
# 되살아난 브로커 혹은 생존 브로커를 통해 ISR 복구를 확인합니다.
docker exec -it $SURVIVOR kafka-topics --describe --bootstrap-server $SURVIVOR:29092 --topic $TARGET_TOPIC

echo -e "\n\n--- 7. 테스트 토픽 삭제 (청소) ---"
# 포트 정보를 추가하여 삭제 명령이 정상적으로 전달되도록 수정했습니다.
docker exec -it $SURVIVOR kafka-topics --delete --bootstrap-server $SURVIVOR:29092 --topic $TARGET_TOPIC
echo "청소 완료!"

echo -e "\n\n테스트가 전부 완료되었습니다."
