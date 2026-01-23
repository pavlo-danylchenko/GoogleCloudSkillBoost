#!/bin/bash

# Task 1. Create topic
gcloud pubsub topics create MyTopic

# Task 2. Add a subscription
gcloud pubsub subscriptions create MySub --topic MyTopic

# Task 4. Publish a message to the topic
gcloud pubsub topics publish MyTopic --message "Hello, World!"

# Task 5. View the message
gcloud pubsub subscriptions pull MySub --auto-ack