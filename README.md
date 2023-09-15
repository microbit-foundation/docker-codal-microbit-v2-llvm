# docker-codal-microbit-v2-llvm


To build the docker image:
```
docker build -t "microbit-llvm" .
```

To run the docker image:

```
docker run --rm -v $(pwd):/home microbit-llvm main.cpp
```

To jump into a container:
```
docker run -it --rm microbit-llvm
```

Steps to extract the hex (Users passing their own main does not work as of now, but this is a good foundation):
```
docker build -t "microbit-llvm" .
docker run --name llvm microbit-llvm:latest
docker start llvm
docker cp llvm:/home/microbit-v2-samples-llvm/build/MICROBIT.hex .
```
