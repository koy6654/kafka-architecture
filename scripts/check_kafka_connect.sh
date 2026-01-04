#!/bin/bash

curl -s localhost:8083/connectors/outbox-connector/status | jq
