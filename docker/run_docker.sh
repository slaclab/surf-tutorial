#!/bin/bash

docker run -ti \
   --net=host \
   -e DISPLAY=${DISPLAY} \
   -v ${HOME}/.Xauthority:/home/${USER}/.Xauthority \
   -v /etc/localtime:/etc/localtime:ro \
   -v ${HOME}:/home/${USER} \
   surf-tutorial-docker-${USER}:latest /bin/bash
