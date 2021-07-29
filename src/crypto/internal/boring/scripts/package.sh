#!/bin/bash
# Copyright 2020 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set -x
set -e
set -u
set -o pipefail

ARCH=${ARCH:-amd64}

if [ "$(./boringssl/build/tool/bssl isfips)" != 1 ]; then
	echo "NOT FIPS"
	exit 2
fi

# Build and run test C++ program to make sure goboringcrypto.h matches openssl/*.h.
# Also collect list of checked symbols in syms.txt

cd godriver
cat >goboringcrypto.cc <<'EOF'
#include <cassert>
#include "goboringcrypto0.h"
#include "goboringcrypto1.h"
#define check_size(t) if(sizeof(t) != sizeof(GO_ ## t)) {printf("sizeof(" #t ")=%d, but sizeof(GO_" #t ")=%d\n", (int)sizeof(t), (int)sizeof(GO_ ## t)); ret=1;}
#define check_func(f) { auto x = f; x = _goboringcrypto_ ## f ; }
#define check_value(n, v) if(n != v) {printf(#n "=%d, but goboringcrypto.h defines it as %d\n", (int)n, (int)v); ret=1;}
int main() {
int ret = 0;
#include "goboringcrypto.x"
return ret;
}
EOF

awk '
BEGIN {
	exitcode = 0
}

# Ignore comments, #includes, blank lines.
/^\/\// || /^#/ || NF == 0 { next }

# Ignore unchecked declarations.
/\/\*unchecked/ { next }

# Check enum values.
!enum && $1 == "enum" && $NF == "{" {
	enum = 1
	next
}
enum && $1 == "};" {
	enum = 0
	next
}
enum && NF == 3 && $2 == "=" {
	name = $1
	sub(/^GO_/, "", name)
	val = $3
	sub(/,$/, "", val)
	print "check_value(" name ", " val ")" > "goboringcrypto.x"
	next
}
enum {
	print FILENAME ":" NR ": unexpected line in enum: " $0 > "/dev/stderr"
	exitcode = 1
	next
}

# Check struct sizes.
/^typedef struct / && $NF ~ /^GO_/ {
	name = $NF
	sub(/^GO_/, "", name)
	sub(/;$/, "", name)
	print "check_size(" name ")" > "goboringcrypto.x"
	next
}

# Check function prototypes.
/^(const )?[^ ]+ \**_goboringcrypto_.*\(/ {
	name = $2
	if($1 == "const")
		name = $3
	sub(/^\**_goboringcrypto_/, "", name)
	sub(/\(.*/, "", name)
	print "check_func(" name ")" > "goboringcrypto.x"
	print name > "syms.txt"
	next
}

{
	print FILENAME ":" NR ": unexpected line: " $0 > "/dev/stderr"
	exitcode = 1
}

END {
	exit exitcode
}
' goboringcrypto.h

cat goboringcrypto.h | awk '
	/^\/\/ #include/ {sub(/\/\//, ""); print > "goboringcrypto0.h"; next}
	/typedef struct|enum ([a-z_]+ )?{|^[ \t]/ {print;next}
	{gsub(/GO_/, ""); gsub(/enum go_/, "enum "); print}
' >goboringcrypto1.h
${CXX:-clang++} -std=c++11 -fPIC -I../boringssl/include -O2 -o a.out  goboringcrypto.cc
./a.out || exit 2

# Prepare copy of libcrypto.a with only the checked functions renamed and exported.
# All other symbols are left alone and hidden.
echo BORINGSSL_bcm_power_on_self_test >>syms.txt
awk '{print "_goboringcrypto_" $0 }' syms.txt >globals.txt
awk '{print $0 " _goboringcrypto_" $0 }' syms.txt >renames.txt
objcopy --globalize-symbol=BORINGSSL_bcm_power_on_self_test ../boringssl/build/crypto/libcrypto.a libcrypto.a

# # attempt alternative to patching mem.c, by defining and linking in weak symbols
# # these cause SIGSEGV in func__goboringcrypto_BORINGSSL_bcm_power_on_self_test
# objdump -t libcrypto.a | grep ' w ' | awk '{print $5}' | tee weak.txt
# echo '#include <openssl/mem.h>' >weak.c
# echo '#define WEAK_SYMBOL_FUNC(rettype, name, args) rettype(*name) args = NULL;' >>weak.c
# grep -r -h -E '^WEAK_SYMBOL_FUNC' ../boringssl >>weak.c
# ${CC:-clang} -c -I../boringssl/include -o weak.o weak.c
# objdump -t weak.o

ld -r --whole-archive -o goboringcrypto.o libcrypto.a # weak.o
objcopy --remove-section=.llvm_addrsig goboringcrypto.o goboringcrypto1.o # b/179161016
objcopy --redefine-syms=renames.txt goboringcrypto1.o goboringcrypto2.o
objcopy --keep-global-symbols=globals.txt goboringcrypto2.o goboringcrypto_linux_${ARCH}.syso

# Done!
ls -l goboringcrypto_linux_${ARCH}.syso
sha256sum goboringcrypto_linux_${ARCH}.syso
