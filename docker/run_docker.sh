#!/bin/bash

# Check OS using uname
if [[ "$(uname)" == "Darwin" ]]; then
   # Check if "xhost +127.0.0.1" has already been set
   if xhost | grep -q "inet:127.0.0.1"; then
      echo "xhost access for 127.0.0.1 is already enabled."
   else
      echo "Enabling xhost access for 127.0.0.1..."
      xhost + 127.0.0.1
   fi
   # macOS system detected
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
