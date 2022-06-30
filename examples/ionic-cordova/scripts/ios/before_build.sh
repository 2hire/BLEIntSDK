# #!/bin/bash

gsed -i -E "s_pod '2hire-BLEIntSDK'\$_pod '2hire-BLEIntSDK', :path => './../../../../'\n\tpod '2hire-secp256k1', :path => './../../../../'\n\tpod '2hire-K1', :path => './../../../../'_" platforms/ios/Podfile

if grep -q "install! 'cocoapods', :deterministic_uuids => false" platforms/ios/Podfile; then
  echo ""
else
  gsed -i -E "s/^(platform :ios, '.*')\$/\1\ninstall! 'cocoapods', :deterministic_uuids => false/" platforms/ios/Podfile
fi

cd platforms/ios
pod install
