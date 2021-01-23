# Delete all containers

`docker stop $(docker ps -a -q)`
`docker rm $(docker ps -a -q)`

# Remove all images

`docker rmi $(docker images -q)`

# Prune volumes

`docker volume prune`