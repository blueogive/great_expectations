# Dedupe-Docker

This repo contains a `Dockerfile` to build
[Docker](https://www.docker.com) image for the
[great expectations](https://greatexpectations.io) Python package.
The foundation of the image is the [Miniconda](https://conda.io/miniconda.html)
environment management system developed by
[Anaconda, Inc](https://www.anaconda.com/). Core packages included in the
image include:
* CPython (3.7)
* Great Expectations

## Usage

To instantiate an ephemeral container from the image, mount the current
directory within the container, and open a bash prompt within the `base` conda
Python environment:

```bash
docker run -it --rm -v $(pwd):/home/docker/work blueogive/great_expectations:latest
```

You will be running as root within the container, but the image includes the
[gosu](https://github.com/tianon/gosu) utility. This allows you to conveniently execute commands as other users:

```bash
gosu 1000:100 python myscript.py
```

Contributions are welcome.
