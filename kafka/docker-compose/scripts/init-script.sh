#!/bin/bash

# Create a test topic with 3 partitions and replication factor of 3
echo "Creating test-topic with 3 partitions and replication factor 3..."
kafka-topics \
    --create \
    --topic test-topic \
    --bootstrap-server kafka1:9092,kafka2:9092,kafka3:9092 \
    --replication-factor 3 \
    --partitions 3

echo "Topic created successfully."
echo ""

# List all available topics
echo "Listing all topics..."
kafka-topics \
    --list \
    --bootstrap-server kafka1:9092,kafka2:9092,kafka3:9092

echo ""

# Describe the test-topic to verify configuration
echo "Describing test-topic configuration..."
kafka-topics \
    --describe \
    --topic test-topic \
    --bootstrap-server kafka1:9092,kafka2:9092,kafka3:9092

echo ""
echo "Initialization complete."


sleep infinity
