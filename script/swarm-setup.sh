#!/bin/bash
# WARNING! This script requires a VPC_ID and KV_IP environment variable to be present!

# cd .. # assuming this script is under PROJECT_ROOT/script

# create kv
# docker-machine create --driver amazonec2 \
# --amazonec2-vpc-id $VPC_ID \
# aws-kv
trap "echo 'trying to clean up swarm machines...'; docker-machine rm aws-manager aws-n1 aws-n2 aws-store; exit 1" SIGHUP SIGINT SIGTERM

# start consul
eval $(docker-machine env aws-kv)
docker-compose -f docker-compose.kv.yml up -d

# create master
docker-machine create -d amazonec2 \
--amazonec2-vpc-id $VPC_ID \
--swarm --swarm-master \
--swarm-discovery="consul://$KV_IP:8500" \
--engine-opt="cluster-store=consul://$KV_IP:8500" \
--engine-opt="cluster-advertise=eth0:2376" \
aws-manager

# create other nodes
docker-machine create -d amazonec2 \
--amazonec2-vpc-id $VPC_ID \
--swarm \
--swarm-discovery="consul://$KV_IP:8500" \
--engine-opt="cluster-store=consul://$KV_IP:8500" \
--engine-opt="cluster-advertise=eth0:2376" \
aws-n1

docker-machine create -d amazonec2 \
--amazonec2-vpc-id $VPC_ID \
--swarm \
--swarm-discovery="consul://$KV_IP:8500" \
--engine-opt="cluster-store=consul://$KV_IP:8500" \
--engine-opt="cluster-advertise=eth0:2376" \
aws-n2

docker-machine create -d amazonec2 \
--amazonec2-vpc-id $VPC_ID \
--swarm \
--swarm-discovery="consul://$KV_IP:8500" \
--engine-opt="cluster-store=consul://$KV_IP:8500" \
--engine-opt="cluster-advertise=eth0:2376" \
aws-store

# Pull images to their respective nodes
eval $(docker-machine env aws-n1)
docker pull shrikrishna/diaspora:dockerfile

eval $(docker-machine env aws-n2)
docker pull shrikrishna/diaspora:dockerfile

eval $(docker-machine env aws-store)
docker pull postgres:latest
docker pull redis:latest

eval $(docker-machine env aws-manager)
docker pull nginx:alpine

# Push mount files to their respective destinations
docker-machine scp -r public aws-manager:$(docker-machine ssh aws-manager pwd)
docker-machine scp nginx.conf aws-manager:$(docker-machine ssh aws-manager pwd)

docker-machine scp config/diaspora.yml aws-n1:$(docker-machine ssh aws-n1 pwd)
docker-machine scp config/database.yml aws-n1:$(docker-machine ssh aws-n1 pwd)

docker-machine scp config/diaspora.yml aws-n2:$(docker-machine ssh aws-n2 pwd)
docker-machine scp config/database.yml aws-n2:$(docker-machine ssh aws-n2 pwd)

# Drumroll...
eval $(docker-machine env --swarm aws-manager)

# Start db and redis services
DIASPORA_DIR=$(docker-machine ssh aws-n1 pwd) docker-compose -f docker-compose.yml -f docker-compose.swarm.yml \
up -d db

# Sleep to allow time for the databases to boot up
echo "waiting 20 seconds for databases to warm up..."
sleep 20

# Bootstrap db
DIASPORA_DIR=$(docker-machine ssh aws-n1 pwd) docker-compose -f docker-compose.yml -f docker-compose.swarm.yml \
run web /bin/bash -l -c "rake db:create db:schema:load"

# Scale web
DIASPORA_DIR=$(docker-machine ssh aws-n1 pwd) docker-compose -f docker-compose.yml -f docker-compose.swarm.yml \
scale web=2

# Start nginx
DIASPORA_DIR=$(docker-machine ssh aws-n1 pwd) docker-compose -f docker-compose.yml -f docker-compose.swarm.yml \
up -d nginx

# Done. Summary
DIASPORA_DIR=$(docker-machine ssh aws-n1 pwd) docker-compose -f docker-compose.yml -f docker-compose.swarm.yml \
ps

echo "Congratulations! Your swarm diaspora setup is complete."
echo "Now go to http://$(docker-machine ip aws-manager)/ on your browser"
