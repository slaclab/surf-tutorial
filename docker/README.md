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

```bash
cd surf-tutorial/docker
./build_docker.sh
./run_docker.sh
```

The docker starts in the local directory: /home/$USER/
