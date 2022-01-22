# Copyright 2020 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# This Docker image builds goboringcrypto_linux_${ARCH}.syso according to the
# Security Policy. To use it, build the image, run it, and then extract
# /boring/godriver/goboringcrypto_linux_${ARCH}.syso.
#
#   $ ARCH=..... # (arm64 or amd64)
#   $ docker build --platform linux/${ARCH} --progress plain --tag boring-${ARCH}:dev
#   $ id=$(docker create boring-${ARCH}:dev)
#   $ docker cp ${id}:/boring/godriver/goboringcrypto_linux_${ARCH}.syso .
#   $ docker rm ${id}
#   $ sha256sum goboringcrypto_linux_${ARCH}.syso # compare to docker output

FROM ubuntu:focal

ENV LANG=C
ENV LANGUAGE=

RUN mkdir /boring
WORKDIR /boring

# !! Needs updated module & policy !!
# Following 140sp3678.pdf [0] page 19, install clang 7.0.1, Go 1.12.7, and
# Ninja 1.9.0, then download and verify BoringSSL.
#
# [0]: https://csrc.nist.gov/CSRC/media/projects/cryptographic-module-validation-program/documents/security-policies/140sp3678.pdf
# !! Needs updated module & policy !!

ARG TARGETARCH
ENV ARCH=${TARGETARCH}

RUN apt-get update && apt-get -y upgrade

ENV APT_INSTALL="apt-get --no-install-recommends -y install"
RUN ${APT_INSTALL} cmake xz-utils wget unzip ca-certificates ninja-build patch

ARG GOLANG_VER=1.16
RUN ${APT_INSTALL} golang-${GOLANG_VER}

ARG CLANG_VER=11
RUN ${APT_INSTALL} clang-${CLANG_VER}

RUN wget -nv https://github.com/google/boringssl/archive/7f02881e96e51f1873afcf384d02f782b48967ca.zip
RUN [ "$(sha256sum 7f02881e96e51f1873afcf384d02f782b48967ca.zip | awk '{print $1}')" = \
        f4384140ca2f33f7897ab471e5348ad6f71fa462968b4cca628381e2bf070710 ]

ENV PATH=${PATH}:/usr/lib/go-${GOLANG_VER}/bin/

ENV CC="/usr/bin/clang-${CLANG_VER}"
ENV CXX="/usr/bin/clang++-${CLANG_VER}"

# Go requires -fPIC for linux/amd64 cgo builds.
# Setting -fPIC only affects the compilation of the non-module code in libcrypto.a,
# because the FIPS module itself is already built with -fPIC.
# Undefine __ELF__ for boringssl/crypto/mem.c, avoid weak symbols for go use.
ENV CFLAGS="-fPIC -U__ELF__"
ENV CXXFLAGS="${CFLAGS}"

ADD patches patches

ADD scripts/build.sh scripts/build.sh
RUN scripts/build.sh

ADD scripts/test.sh scripts/test.sh
RUN scripts/test.sh

ADD goboringcrypto.h godriver/goboringcrypto.h
ADD scripts/package.sh scripts/package.sh
RUN scripts/package.sh
