#!/bin/bash
set -e
cd "/mnt/d/4. PROJECT/13. Mobile/Indexsafe Evolution/Mobile"
echo "=== Building APK Release ==="
/home/lulushermawan/flutter/bin/flutter build apk --release --android-skip-build-dependency-validation
echo "=== Building AppBundle Release ==="
/home/lulushermawan/flutter/bin/flutter build appbundle --release --android-skip-build-dependency-validation
echo "=== BUILD SUCCESSFUL ==="

