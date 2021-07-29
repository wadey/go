#!/bin/bash
# Copyright 2020 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set -x
set -e
set -u
set -o pipefail

cd boringssl
time go run util/all_tests.go

cd ssl/test/runner
# extend timeout for emulated testing
# tail output to prevent reaching docker log limit
time go test -timeout 30m | tail -2
