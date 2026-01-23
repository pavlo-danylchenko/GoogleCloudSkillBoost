#!/bin/bash

# Task 1. Pub/Sub topics
gcloud pubsub topics create myTopic

# Task 2. Pub/Sub subscriptions
gcloud  pubsub subscriptions create --topic myTopic mySubscription