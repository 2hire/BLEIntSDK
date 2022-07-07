Pod::Spec.new do |s|
  s.name             = '2hire-K1'
  s.version          = '0.0.2-beta.11'
  s.summary          = 'secp256k1 Elliptic Curve in Swift.'

  s.swift_version = '5'

  s.description      = <<-DESC
  K1 is Swift wrapper around libsecp256k1 (bitcoin-core/secp256k1), offering ECDSA, Schnorr (BIP340) and ECDH features.
                       DESC

  s.homepage         = 'https://github.com/2hire/BLEIntSDK'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '2hire' => 'info@2hire.io' }
  s.source           = { :git => 'https://github.com/2hire/BLEIntSDK.git', :tag => 'v' + String(s.version.to_s), :submodules => true }

  s.ios.deployment_target = '13.0'

  s.dependency '2hire-secp256k1', s.version.to_s
  s.dependency 'BigInt', '~> 5.2'

  s.frameworks = 'CryptoKit'
  s.source_files = ['packages/sdk/ios/K1/Classes/**/*']
end
