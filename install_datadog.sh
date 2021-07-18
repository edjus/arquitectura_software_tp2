#!/bin/bash

DD_URL='https://raw.githubusercontent.com/DataDog/dd-agent/master/packaging/datadog-agent/source/install_agent.sh'

export DD_API_KEY=$1

echo '----- Install Datadog Agent -----'
curl -L -o- ${DD_URL} | bash

echo '----- Turn on process monitoring in Datadog Agent -----'
sudo su -c "sed 's/# process_agent_enabled: false/process_agent_enabled: true/' /etc/dd-agent/datadog.conf > /etc/dd-agent/tmp.conf"
sudo mv /etc/dd-agent/tmp.conf /etc/dd-agent/datadog.conf

echo '----- Restart Datadog Agent -----'
sudo service datadog-agent restart
