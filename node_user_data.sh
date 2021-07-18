#!/bin/bash

################################################
# Install NVM in the user space (not as root)
# (based on https://gist.github.com/matthewflanneryaustralia/37001f99dddcfa486dc637607a2b3990).
#
# Since this script (user_data) runs as root, the approach is to
# create a temporary script in the machine, and then run that script
# as the ec2-user (instead of root).
################################################
USER_SCRIPT="/tmp/user_space_script.sh"

cat > "$USER_SCRIPT" << EOF
echo '------- Install tools -------'
sudo yum -y install gcc-c++

echo '------- Download nvm and install it -------'
curl -o- "https://raw.githubusercontent.com/creationix/nvm/v0.34.0/install.sh" | bash

echo '------- Load nvm and add it to .bashrc -------'
echo 'export NVM_DIR="/home/ec2-user/.nvm"' >> /home/ec2-user/.bashrc
echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm' >> /home/ec2-user/.bashrc

# Dot source the files to ensure that variables are available within the current shell
. /home/ec2-user/.profile
. /home/ec2-user/.bashrc
. $NVM_DIR/nvm.sh

echo '------- Install node and set default version -------'
nvm alias default ${node_version}
nvm install ${node_version}
nvm use ${node_version}

echo '------- Log node and npm versions -------'
npm version

echo '------- Provision instance with code -------'
cd /home/ec2-user/
curl ${src_location} > src.zip
unzip src.zip

echo '------- Install dependencies -------'
npm install

echo '------- Start application -------'
nohup node . > node.out 2> node.err < /dev/null &

EOF

chown ec2-user "$USER_SCRIPT" && chmod a+x "$USER_SCRIPT"
sleep 1; su - ec2-user -c "$USER_SCRIPT"


################################################
# Install and start the datadog agent
################################################

DD_URL='https://raw.githubusercontent.com/DataDog/dd-agent/master/packaging/datadog-agent/source/install_agent.sh'

export DD_API_KEY=${datadog_key}

echo '----- Install Datadog Agent -----'
curl -L -o- $DD_URL | bash

echo '----- Turn on process monitoring in Datadog Agent -----'
sudo su -c "sed 's/# process_agent_enabled: false/process_agent_enabled: true/' /etc/dd-agent/datadog.conf > /etc/dd-agent/tmp.conf"
sudo mv /etc/dd-agent/tmp.conf /etc/dd-agent/datadog.conf

echo '----- Restart Datadog Agent -----'
sudo service datadog-agent restart
