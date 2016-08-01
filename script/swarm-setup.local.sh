#!/bin/bash
# WARNING! This script requires a VPC_ID and $(docker-machine ip swarm-kv) environment variable to be present!

# cd .. # assuming this script is under PROJECT_ROOT/script

# create kv
# docker-machine create --driver amazonec2 \
# --amazonec2-vpc-id $VPC_ID \
# swarm-kv
trap "echo 'trying to clean up swarm machines...'; docker-machine rm swarm-manager swarm-n1 swarm-n2 swarm-store swarm-kv; exit 1" SIGHUP SIGINT SIGTERM

# start consul
docker-machine create -d virtualbox --virtualbox-host-dns-resolver swarm-kv
eval $(docker-machine env swarm-kv)
docker load -i consul.tar
docker-compose -f docker-compose.kv.yml up -d
# $(docker-machine ip swarm-kv)=$(docker-machine ip swarm-kv)

# create master
docker-machine create -d virtualbox \
--swarm --swarm-master \
--swarm-discovery="consul://$(docker-machine ip swarm-kv):8500" \
--engine-opt="cluster-store=consul://$(docker-machine ip swarm-kv):8500" \
--engine-opt="cluster-advertise=eth0:2376" \
--virtualbox-host-dns-resolver \
swarm-manager

# create other nodes
docker-machine create -d virtualbox \
--swarm \
--swarm-discovery="consul://$(docker-machine ip swarm-kv):8500" \
--engine-opt="cluster-store=consul://$(docker-machine ip swarm-kv):8500" \
--engine-opt="cluster-advertise=eth0:2376" \
--virtualbox-host-dns-resolver \
swarm-n1

docker-machine create -d virtualbox \
--swarm \
--swarm-discovery="consul://$(docker-machine ip swarm-kv):8500" \
--engine-opt="cluster-store=consul://$(docker-machine ip swarm-kv):8500" \
--engine-opt="cluster-advertise=eth0:2376" \
--virtualbox-host-dns-resolver \
swarm-n2

docker-machine create -d virtualbox \
--swarm \
--swarm-discovery="consul://$(docker-machine ip swarm-kv):8500" \
--engine-opt="cluster-store=consul://$(docker-machine ip swarm-kv):8500" \
--engine-opt="cluster-advertise=eth0:2376" \
--virtualbox-host-dns-resolver \
swarm-store

# Pull images to their respective nodes
eval $(docker-machine env swarm-n1)
# docker pull shrikrishna/diaspora:dockerfile
docker load -i diaspora.tar

eval $(docker-machine env swarm-n2)
# docker pull shrikrishna/diaspora:dockerfile
docker load -i diaspora.tar

eval $(docker-machine env swarm-store)
# docker pull postgres:latest
# docker pull redis:latest
docker load -i postgres.tar

eval $(docker-machine env swarm-manager)
# docker pull nginx:alpine
docker load -i nginx.tar

# Push mount files to their respective destinations
# docker-machine scp -r public swarm-manager:$(docker-machine ssh swarm-manager pwd)
# docker-machine scp nginx.conf swarm-manager:$(docker-machine ssh swarm-manager pwd)

# docker-machine scp config/diaspora.yml swarm-n1:$(docker-machine ssh swarm-n1 pwd)
# docker-machine scp config/database.yml swarm-n1:$(docker-machine ssh swarm-n1 pwd)

# docker-machine scp config/diaspora.yml swarm-n2:$(docker-machine ssh swarm-n2 pwd)
# docker-machine scp config/database.yml swarm-n2:$(docker-machine ssh swarm-n2 pwd)

# Drumroll...
eval $(docker-machine env --swarm swarm-manager)

# # Start db service
# DIASPORA_DIR=$(docker-machine ssh swarm-n1 pwd) docker-compose -f docker-compose.yml -f docker-compose.swarm.local.yml \
# up -d db

# # Sleep to allow time for the databases to boot up
# echo "waiting 20 seconds for databases to warm up..."
# sleep 20

# # Bootstrap db
# DIASPORA_DIR=$(docker-machine ssh swarm-n1 pwd) docker-compose -f docker-compose.yml -f docker-compose.swarm.local.yml \
# run web /bin/bash -l -c "rake db:create db:schema:load"


# # Scale web
# DIASPORA_DIR=$(docker-machine ssh swarm-n1 pwd) docker-compose -f docker-compose.yml -f docker-compose.swarm.local.yml \
# scale web=2

# # Start nginx
# DIASPORA_DIR=$(docker-machine ssh swarm-n1 pwd) docker-compose -f docker-compose.yml -f docker-compose.swarm.local.yml \
# up -d nginx

# # Done. Summary
# DIASPORA_DIR=$(docker-machine ssh swarm-n1 pwd) docker-compose -f docker-compose.yml -f docker-compose.swarm.local.yml \
# ps

echo "Congratulations! Your swarm diaspora setup is complete."
echo "Now go to http://$(docker-machine ip swarm-manager)/ on your browser"
