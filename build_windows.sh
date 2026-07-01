#!/bin/bash
# Set MSVC environment
export VSINSTALLDIR="D:\VS"
export VCINSTALLDIR="D:\VS\VC"
export WindowsSdkDir="C:\Program Files (x86)\Windows Kits\10"
export WindowsSDKVersion="10.0.26100.0"

# Add MSVC to PATH
MSVC_BIN="D:\VS\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64"
SDK_BIN="C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64"
export PATH="$MSVC_BIN:$SDK_BIN:$PATH"

# Set INCLUDE and LIB
export INCLUDE="D:\VS\VC\Tools\MSVC\14.44.35207\include;D:\VS\VC\Tools\MSVC\14.44.35207\atlmfc\include;C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\ucrt;C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\um;C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\shared"

export LIB="D:\VS\VC\Tools\MSVC\14.44.35207\lib\x64;D:\VS\VC\Tools\MSVC\14.44.35207\atlmfc\lib\x64;C:\Program Files (x86)\Windows Kits\10\Lib\10.0.26100.0\ucrt\x64;C:\Program Files (x86)\Windows Kits\10\Lib\10.0.26100.0\um\x64"

echo "MSVC environment configured"
echo "cl.exe version:"
cl.exe 2>&1 | head -2 || echo "cl.exe not found"

echo ""
echo "Building FileShare for Windows..."
export PATH="/d/flutter/bin:$PATH"
cd /d/fileshare
flutter build windows --debug 2>&1
