FROM ubuntu:22.04

# Install system tools
RUN DEBIAN_FRONTEND=noninteractive \
   apt-get update && \
   apt-get install -y --no-install-recommends tzdata && \
   apt-get install -y \
   python3 \
   python3-dev \
   python3-pip \
   git \
   git-lfs \
   build-essential \
   tclsh \
   gtkwave \
   ghdl \
   locales

RUN pip3 install \
   cocotb \
   cocotbext-axi \
   cocotb-test \
   cocotb-bus \
   coverage \
   pytest \
   pytest-cov 

RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8
RUN git lfs install

ARG uid
ARG gid
ARG user
RUN groupadd -g ${gid} -o ${user}
RUN useradd -m -N --gid ${gid} --shell /bin/bash --uid ${uid} ${user}

USER ${user}
WORKDIR /home/${user}
