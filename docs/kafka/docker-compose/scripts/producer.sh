#!/bin/bash



kafka-console-producer \
    --broker-list kafka1:9092,kafka2:9092,kafka3:9092 \
    --topic test-topic