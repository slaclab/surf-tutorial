#!/bin/bash

# Check OS using uname
if [[ "$(uname)" == "Darwin" ]]; then
   # macOS system detected
   xhost + 127.0.0.1
   DISPLAY='host.docker.internal:0'
else
   # Assuming Linux if not macOS
   DISPLAY=${DISPLAY}
fi

# Start the docker
docker run -ti \
   --net=host \
   -e DISPLAY=$DISPLAY \
   -v ${HOME}/.Xauthority:/home/${USER}/.Xauthority \
   -v /etc/localtime:/etc/localtime:ro \
   -v ${HOME}:/home/${USER} \
   surf-tutorial-docker-${USER}:latest /bin/bash
