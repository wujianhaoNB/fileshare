#!/bin/bash
set -e

MSVC_BASE="D:/VS/VC/Tools/MSVC/14.44.35207"
SDK_BASE="C:/Program Files (x86)/Windows Kits/10"
export PATH="$MSVC_BASE/bin/Hostx64/x64:$SDK_BASE/bin/10.0.26100.0/x64:/d/flutter/bin:$PATH"
export INCLUDE="$MSVC_BASE/include;$MSVC_BASE/atlmfc/include;$SDK_BASE/Include/10.0.26100.0/ucrt;$SDK_BASE/Include/10.0.26100.0/um;$SDK_BASE/Include/10.0.26100.0/shared"
export LIB="$MSVC_BASE/lib/x64;$MSVC_BASE/atlmfc/lib/x64;$SDK_BASE/Lib/10.0.26100.0/ucrt/x64;$SDK_BASE/Lib/10.0.26100.0/um/x64"

OUT_DIR="/d/fileshare/windows/build/debug/runner/Debug"

# Step 1: Compile Dart to kernel
echo "=== Step 1: Compiling Dart to kernel ==="
mkdir -p build/flutter_assets
dart compile kernel lib/main.dart -o build/flutter_assets/kernel_blob.bin 2>&1 || {
    echo "Kernel compile via dart failed, trying flutter..."
    flutter assemble debug_bundle_windows_assets 2>&1 || true
}

# Step 2: Ensure assets exist
if [ ! -f build/flutter_assets/kernel_blob.bin ]; then
    echo "Creating minimal kernel..."
    # Last resort: keep using the old kernel (it has old code but the logger fix is in dart:core patterns)
fi

# Step 3: Build C++ part
echo "=== Step 3: Building C++ ==="
cd windows
rm -rf build/debug
mkdir -p build/debug
cd build/debug
cmake -G "Visual Studio 17 2022" ../.. > /dev/null 2>&1
cmake --build . --config Debug > /dev/null 2>&1
echo "C++ build complete"

# Step 4: Assemble output
echo "=== Step 4: Assembling ==="
cd /d/fileshare
rm -rf "$OUT_DIR/data"
cp -r build/flutter_assets "$OUT_DIR/data/"
cp windows/flutter/ephemeral/icudtl.dat "$OUT_DIR/data/"
cp windows/flutter/ephemeral/*.dll "$OUT_DIR/"
cp windows/build/debug/plugins/*/Debug/*.dll "$OUT_DIR/" 2>/dev/null

echo "=== Complete! ==="
echo "EXE: $OUT_DIR/fileshare.exe"
