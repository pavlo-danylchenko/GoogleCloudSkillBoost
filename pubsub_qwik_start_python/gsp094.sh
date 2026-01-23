#!/bin/bash

# Task 1. Create a virtual environment
# Install the virtualenv environment:
sudo apt-get install -y virtualenv

# Build the virtual environment:
python3 -m venv venv
# Activate the virtual environment:
source venv/bin/activate

# Task 2. Install the client library
pip install --upgrade google-cloud-pubsub
git clone https://github.com/googleapis/python-pubsub.git
cd python-pubsub/samples/snippets

# Task 3. Pub/Sub - the Basics
# Read docs

# Task 4. Create a topic
python publisher.py $GOOGLE_CLOUD_PROJECT create MyTopic

# Task 5. Create a subscription
python subscriber.py $GOOGLE_CLOUD_PROJECT create MyTopic MySub

# Task 6. Publish messages
# gcloud pubsub topics publish MyTopic --message "Hello"

# Task 7. View messages
# python subscriber.py $GOOGLE_CLOUD_PROJECT receive MySub
