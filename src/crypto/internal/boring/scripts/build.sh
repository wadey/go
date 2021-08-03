#!/bin/bash
# Copyright 2020 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set -x
set -e
set -u
set -o pipefail

id
date

# !! Needs updated module & policy !!
# Build BoringCrypto libcrypto.a.
# Following https://csrc.nist.gov/CSRC/media/projects/cryptographic-module-validation-program/documents/security-policies/140sp3678.pdf page 19.
# !! Needs updated module & policy !!

tar xJf boringssl-*z

cd boringssl

mkdir build && cd build

cmake -GNinja -DFIPS=1 -DCMAKE_BUILD_TYPE=Release ..
ninja -v
