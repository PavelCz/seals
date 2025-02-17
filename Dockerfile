# base stage contains just binary dependencies.
# This is used in the CI build.
FROM nvidia/cuda:10.0-runtime-ubuntu18.04 AS base
ARG DEBIAN_FRONTEND=noninteractive

RUN    apt-get update -q \
    && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    ffmpeg \
    git \
    libgl1-mesa-dev \
    libgl1-mesa-glx \
    libglew-dev \
    libosmesa6-dev \
    net-tools \
    parallel \
    patchelf \
    python3.8 \
    python3.8-dev \
    python3-pip \
    rsync \
    software-properties-common \
    unzip \
    vim \
    virtualenv \
    xpra \
    xserver-xorg-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV LANG C.UTF-8

RUN    mkdir -p /root/.mujoco \
    && curl -o mjpro150.zip https://www.roboti.us/download/mjpro150_linux.zip \
    && unzip mjpro150.zip -d /root/.mujoco \
    && rm mjpro150.zip \
    && curl -o /root/.mujoco/mjkey.txt https://www.roboti.us/file/mjkey.txt

# Set the PATH to the venv before we create the venv, so it's visible in base.
# This is since we may create the venv outside of Docker, e.g. in CI
# or by binding it in for local development.
ENV PATH="/venv/bin:$PATH"
ENV LD_LIBRARY_PATH /root/.mujoco/mjpro150/bin:${LD_LIBRARY_PATH}

# Run Xdummy mock X server by default so that rendering will work.
COPY ci/xorg.conf /etc/dummy_xorg.conf
COPY ci/Xdummy-entrypoint.py /usr/bin/Xdummy-entrypoint.py
ENTRYPOINT ["/usr/bin/Xdummy-entrypoint.py"]

# python-req stage contains Python venv, but not code.
# It is useful for development purposes: you can mount
# code from outside the Docker container.
FROM base as python-req

WORKDIR /seals
# Copy only necessary dependencies to build virtual environment.
# This minimizes how often this layer needs to be rebuilt.
COPY ./setup.py ./setup.py
COPY ./README.md ./README.md
COPY ./src/seals/version.py ./src/seals/version.py
COPY ./ci/build_venv.sh ./ci/build_venv.sh
RUN    /seals/ci/build_venv.sh /venv \
    && rm -rf $HOME/.cache/pip

# full stage contains everything.
# Can be used for deployment and local testing.
FROM python-req as full

# Delay copying (and installing) the code until the very end
COPY . /seals
# Build a wheel then install to avoid copying whole directory (pip issue #2195)
RUN python3 setup.py sdist bdist_wheel
RUN pip install --upgrade dist/seals-*.whl

# Default entrypoints
CMD ["pytest", "-n", "auto", "-vv", "tests/"]
