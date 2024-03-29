Pod::Spec.new do |s|
  s.name             = '2hire-secp256k1'
  s.version          = '0.1.3'
  s.summary          = 'secp256k1 Elliptic Curve'

  s.swift_version = '5'
  s.module_name   = 'secp256k1'

  s.description      = <<-DESC
    libsecp256k1 (bitcoin-core/secp256k1), offering ECDSA, Schnorr (BIP340) and ECDH features.
                       DESC

  s.homepage         = 'https://github.com/2hire/BLEIntSDK/blob/v' + String(s.version.to_s) + '/packages/sdk/ios/secp256k1'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '2hire' => 'info@2hire.io' }
  s.source           = { :git => 'https://github.com/2hire/BLEIntSDK.git', :tag => 'v' + String(s.version.to_s), :submodules => true }

  s.source_files = [
    'packages/sdk/ios/secp256k1/libsecp256k1/src/modules/*/*.{h,c}',
    'packages/sdk/ios/secp256k1/libsecp256k1/include/*.{h,c}',
    'packages/sdk/ios/secp256k1/libsecp256k1/contrib/*.{h,c}',
    'packages/sdk/ios/secp256k1/libsecp256k1/src/*.{h,c}',
    'packages/sdk/ios/secp256k1/src/*.{h,c}',
    'packages/sdk/ios/secp256k1/*.h'
  ]

  s.public_header_files = [
    'packages/sdk/ios/secp256k1/libsecp256k1/include/*.h',
    'packages/sdk/ios/secp256k1/src/*.{h}'
  ]

  s.exclude_files = [
    'packages/sdk/ios/secp256k1/libsecp256k1/src/asm',
    'packages/sdk/ios/secp256k1/libsecp256k1/src/bench.c',
    'packages/sdk/ios/secp256k1/libsecp256k1/src/bench_ecmult.c',
    'packages/sdk/ios/secp256k1/libsecp256k1/src/bench_internal.c',
    'packages/sdk/ios/secp256k1/libsecp256k1/src/modules/extrakeys/tests_impl.h',
    'packages/sdk/ios/secp256k1/libsecp256k1/src/modules/schnorrsig/tests_impl.h',
    'packages/sdk/ios/secp256k1/libsecp256k1/src/precompute_ecmult.c',
    'packages/sdk/ios/secp256k1/libsecp256k1/src/precompute_ecmult_gen.c',
    'packages/sdk/ios/secp256k1/libsecp256k1/src/tests_exhaustive.c',
    'packages/sdk/ios/secp256k1/libsecp256k1/src/tests.c',
    'packages/sdk/ios/secp256k1/libsecp256k1/src/valgrind_ctime_test.c',
    'packages/sdk/ios/secp256k1/libsecp256k1/configure.ac',
    'packages/sdk/ios/secp256k1/libsecp256k1/src/modules/extrakeys/Makefile.am.include',
    'packages/sdk/ios/secp256k1/libsecp256k1/src/modules/ecdh/Makefile.am.include',
    'packages/sdk/ios/secp256k1/libsecp256k1/src/modules/schnorrsig/Makefile.am.include',
    'packages/sdk/ios/secp256k1/libsecp256k1/src/modules/recovery/Makefile.am.include',
    'packages/sdk/ios/secp256k1/libsecp256k1/autogen.sh',
    'packages/sdk/ios/secp256k1/libsecp256k1/libsecp256k1.pc.in',
    'packages/sdk/ios/secp256k1/libsecp256k1/doc',
    'packages/sdk/ios/secp256k1/libsecp256k1/contrib',
    'packages/sdk/ios/secp256k1/libsecp256k1/ci',
    'packages/sdk/ios/secp256k1/libsecp256k1/sage',
    'packages/sdk/ios/secp256k1/libsecp256k1/build-aux',
    'packages/sdk/ios/secp256k1/libsecp256k1/README.md',
    'packages/sdk/ios/secp256k1/libsecp256k1/Makefile.am',
    'packages/sdk/ios/secp256k1/libsecp256k1/COPYING',
    'packages/sdk/ios/secp256k1/libsecp256k1/SECURITY.md'
  ]

  s.pod_target_xcconfig = {
    'SWIFT_INCLUDE_PATHS' => '${PODS_ROOT}',
    'OTHER_CFLAGS' => '-DENABLE_MODULE_ECDH=1 -DENABLE_MODULE_RECOVERY=1 -DENABLE_MODULE_SCHNORRSIG=1 -DENABLE_MODULE_EXTRAKEYS=1 -DECMULT_WINDOW_SIZE=15 -DECMULT_GEN_PREC_BITS=4 -Wno-unused-function -Wno-shorten-64-to-32',
    'HEADER_SEARCH_PATHS' => '"${PODS_ROOT}"',
    'DEFINES_MODULE' => 'YES' 
  }
end
