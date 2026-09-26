#!/bin/bash


kafka-console-consumer \
    --bootstrap-server kafka1:9092,kafka2:9092,kafka3:9092 \
    --topic test-topic \
    --from-beginning