#!/bin/bash
# Direct build using MSVC toolchain (bypasses Flutter's VS detection)

export PATH="/d/flutter/bin:$PATH"

# Set MSVC environment
MSVC_BASE="D:/VS/VC/Tools/MSVC/14.44.35207"
SDK_BASE="C:/Program Files (x86)/Windows Kits/10"

# Add to PATH (using Unix-style paths for Git Bash)
export PATH="$MSVC_BASE/bin/Hostx64/x64:$SDK_BASE/bin/10.0.26100.0/x64:$PATH"

# Set INCLUDE
export INCLUDE="$MSVC_BASE/include"
export INCLUDE="$INCLUDE;$MSVC_BASE/atlmfc/include"
export INCLUDE="$INCLUDE;$SDK_BASE/Include/10.0.26100.0/ucrt"
export INCLUDE="$INCLUDE;$SDK_BASE/Include/10.0.26100.0/um"
export INCLUDE="$INCLUDE;$SDK_BASE/Include/10.0.26100.0/shared"
export INCLUDE="$INCLUDE;$SDK_BASE/Include/10.0.26100.0/winrt"
export INCLUDE="$INCLUDE;$SDK_BASE/Include/10.0.26100.0/cppwinrt"

# Set LIB
export LIB="$MSVC_BASE/lib/x64"
export LIB="$LIB;$MSVC_BASE/atlmfc/lib/x64"
export LIB="$LIB;$SDK_BASE/Lib/10.0.26100.0/ucrt/x64"
export LIB="$LIB;$SDK_BASE/Lib/10.0.26100.0/um/x64"

echo "=== Environment ==="
echo "cl.exe: $(which cl.exe 2>/dev/null || echo 'not found')"
echo "cmake: $(which cmake 2>/dev/null || echo 'not found')"

echo ""
echo "=== Generating Flutter cmake files ==="
cd /d/fileshare
flutter build windows --debug 2>&1 | tail -20

