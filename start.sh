#!/bin/bash

DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -r "./terraform.tfvars" ]; then
  echo "Could not find 'terraform.tfvars'. Are you sure you're running this from the project's root dir?"
  exit 1
fi

if [ ! -d "./.terraform" ]; then
  echo "Could not find '.terraform/'. Initializing terraform..."
  terraform init
fi

# Prepare Lambda zipfile.
echo "##### Zipping lambda source code #####"
$DIR/python-lambda/zip

# Create infrastructure. This also changes the python IP in the node app so that they can communicate
# The -auto-approve flag makes it not to ask for plan approval. Use at your own risk!
echo "##### Applying terraform infrastructure #####"
terraform apply -auto-approve

# Once the infrastructure is created, the node process are running (The node_user_data.sh is run when
# applying the infrastructure, that is the one that starts that process) but the python one no.
# So, it's important to start it in the appropiate server:
echo "##### Starting python app #####"
$DIR/python/start

# The node code that is actually running has a wrong python server URL, so we must zip it again with the
# correct IP that has been changed when applying the python.tf infrastructure. The redis.tf file does the same
# with redis DNS.
echo "##### Zipping node source code #####"
$DIR/node/zip
# And we must upload the src.zip file to the S3 bucket (Which name is in the source_location file) by using the aws-cli.
echo "##### Uploading node source code to S3 bucket #####"
aws s3 cp $DIR/node/src.zip "s3://$(cat $DIR/source_location)/src.zip"

# By using the aws-cli, we get the node server IPs, so that we can update their code with the zip file.
# Of course you can also get this data from the EC2 console under the name "IPv4 Public IP".
# This command returns a tab-separated string with the IPs, so we transform them to end-lines
echo "##### Getting node instances IPs #####"
aws ec2 describe-instances --query "Reservations[*].Instances[*].PublicIpAddress" --filters "Name=tag-value,Values=tp_arqsoft_node_asg_instance" --output=text | tr '\t' '\n' > $DIR/node/ips

# Finally, with those IPs, we update the node instances code with the src code uploaded to S3
# The "3" indicates the file descriptor to run that loop, so that it doesn't interfere with stdin
while IFS='' read -r ip <&3 || [[ -n "$ip" ]]; do
    echo "##### Updating node source code of instance with IP $ip #####"
    $DIR/node/update "$ip"
done 3< $DIR/node/ips
