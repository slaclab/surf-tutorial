# Prerequisites for Linux

To run this on a build server you need to first install docker:
```bash
sudo apt-get install docker docker.io
```

You must then add your user id to the docker group in /etc/groups
```bash
sudo usermod -a -G docker $USER
```

You can then enable and start the docker service on the machine:
```bash
sudo systemctl enable docker
sudo systemctl start docker
```

`Log out` and `log in` again into the server!!!!!

You can then build and run the docker image with the commands:

# Prerequisites for macOS

1. **Install Docker for Mac**: Download and install Docker for Mac from the [official website](https://docs.docker.com/docker-for-mac/install/).

2. **Install XQuartz**: XQuartz is required for X11 forwarding to allow GUI applications within Docker containers to be displayed on your Mac.
   - Download XQuartz from [XQuartz.org](https://www.xquartz.org/).
   - Install XQuartz and then log out and log back in to your Mac to ensure the installation is complete.

3. **Configure XQuartz**: After logging back in, open XQuartz, and in the XQuartz preferences, go to the "Security" tab and ensure "Allow connections from network clients" is checked.

4. **Start XQuartz**: Before running your Docker container, start XQuartz from your Applications folder.

There's no need to manually add your user to the Docker group or enable the Docker service as in Linux. Docker for Mac handles these aspects automatically.

# How to build and run the docker

```bash
# Before the docker environment:
cd surf-tutorial/docker
./build_docker.sh
./run_docker.sh

# In the docker environment:
cd <PATH to GIT clone in home space>/surf-tutorial/labs
...
...
...
```

The docker starts in the local directory: /home/$USER/
