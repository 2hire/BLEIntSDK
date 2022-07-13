#!/usr/bin/env bash

echo "Creating .env.local"

cat <<EOF >.env.local
TWOAA_CLIENT_ID=$APP_TWOAA_CLIENT_ID
TWOAA_HOST=$APP_TWOAA_HOST
TWOAA_SECRET=$APP_TWOAA_SECRET
EOF

if [[ -z "${APP_TEST_BOARD}" ]]; then
  echo "APP_TEST_BOARD is not defined"
else
  echo "Using mock data"

  cat <<EOF >.env.local
TEST_BOARD=$APP_TEST_BOARD
EOF
fi

if [ -z ${APPCENTER_XCODE_PROJECT+x} ]; then
  echo "Android Project, generating signature file"
  echo $APPCENTER_SIGNING_KEYSTORE_ENCODED | base64 -d >./android/app/app-key.keystore
fi
