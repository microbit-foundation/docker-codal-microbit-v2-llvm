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