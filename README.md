# surf-tutorial

This tutorial is designed for users learning how to use SURF framework
Everything in this tutorial is `open source`!!!
So there are no "pay barriers" or licensing required to get started.

<!--- ######################################################## -->

# Clone the GIT repository

Install git large filesystems (git-lfs) in your .gitconfig (1-time step per unix environment)
```bash
$ git lfs install
```

Clone the git repo with git-lfs enabled
```bash
$ git clone --recursive https://github.com/slaclab/surf-tutorial.git
```

Note: `recursive flag` used to initialize all submodules within the clone

<!--- ######################################################## -->

# System Requirements

There are two method for running this tutorial:
- system install of the required tools
- Run in a docker container

### System Install Method

It is recommend to use Ubuntu 2022.04 LTS (or later Ubuntu release) for these labs:

Here are the packages to install:
```bash
# Install the apt packages
sudo apt install \
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

# Install the pip packages
sudo pip install -r pip_requirements.txt
```

### Docker Container Method

Please refer to the [docker README.md](https://github.com/slaclab/surf-tutorial/blob/main/docker/README.md)


<!--- ######################################################## -->

# Summary of SURF Tutorial labs

This project provides different labs to help users get familiar with the SURF framework

- `labs/01-AXI-Lite_register_endpoint`: demonstrates how to use the SURF AXI-Lite helper function procedures to quickly make an endpoint
- `labs/02-AXI-stream_module`: demonstrates how to use the SURF's AXI stream frame work for both a sourcing and sinking a stream

The intent of this repo is to add more labs in the future.  Feel free to reach out and make requests. 

<!--- ######################################################## -->
