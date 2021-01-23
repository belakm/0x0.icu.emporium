# Remove all images

`docker rmi $(docker images -q)`

# Delete all containers

`docker rm $(docker ps -a -q)`