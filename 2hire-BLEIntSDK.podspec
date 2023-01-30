Pod::Spec.new do |s|
  s.name             = '2hire-BLEIntSDK'
  s.version          = '0.1.1'
  s.summary          = 'SDK for BLE integratation'

  s.description      = <<-DESC
  2hire-BLEIntSDK is an SDK to interact via Bluetooth with 2hireBox powered vehicles.
  For more info check https://2hire.io
                       DESC

  s.homepage         = 'https://github.com/2hire/BLEIntSDK/blob/v' + String(s.version.to_s) + '/packages/sdk/ios/core'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '2hire' => 'info@2hire.io' }
  s.source           = { :git => 'https://github.com/2hire/BLEIntSDK.git', :tag => 'v' + String(s.version.to_s) }

  s.ios.deployment_target = '13.0'
  s.swift_versions        = '5'
  s.module_name           = "BLEIntSDK"

  s.source_files = 'packages/sdk/ios/core/BLEIntSDK/Classes/**/*'

  s.dependency '2hire-K1', s.version.to_s
  s.dependency 'Logging', '~> 1.4'

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'packages/sdk/ios/core/BLEIntSDK/Tests/**/*'
  end  
end
