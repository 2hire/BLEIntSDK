#!/bin/bash

if grep -q "custom.library.reference.1" platforms/android/project.properties; then
  echo ""
else
  echo "" >>platforms/android/project.properties
  echo "custom.library.reference.1=twohire-bleintsdk-android:./../../../../packages/sdk/android/core" >>platforms/android/project.properties
fi
