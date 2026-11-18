FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    TZ=UTC

RUN apt-get update && apt-get install -y --no-install-recommends \
	bc \
	bison \
	build-essential \
	ca-certificates \
	ccache \
	clang \
	cmake \
	cpio \
	curl \
	file \
	flex \
	g++ \
	gawk \
	gettext \
	git \
	libelf-dev \
	libncurses-dev \
	libssl-dev \
	ncurses-term \
	patch \
	perl \
	python3 \
	python3-pip \
	python3-setuptools \
	python3-venv \
	quilt \
	rsync \
	subversion \
	swig \
	time \
	unzip \
	wget \
	xsltproc \
	zlib1g-dev \
	zstd \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash build && \
    mkdir -p /home/build && chown build:build /home/build

USER build
WORKDIR /home/build
