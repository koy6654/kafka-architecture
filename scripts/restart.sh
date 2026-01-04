#!/bin/bash
echo "Remove kafka containers..."
docker-compose -f ./docker-compose.kraft.yml down -v
sleep 3;

echo "Remove kafka logs..."
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
rm -rf $PROJECT_ROOT/tmp
ls -al | grep tmp

echo "Create new kafka containers"
docker-compose -f ./docker-compose.kraft.yml up -d

echo "Done!"
