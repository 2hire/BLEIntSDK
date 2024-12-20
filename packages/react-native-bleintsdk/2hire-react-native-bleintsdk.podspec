require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "2hire-react-native-bleintsdk"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "15.0" }
  s.source       = { :git => "https://github.com/2hire/BLEIntSDK.git", :tag => "#{s.version}" }

  s.source_files = "ios/*.{h,m,mm,swift}"

  s.dependency "React-Core"
  s.dependency "2hire-BLEIntSDK", "0.1.8"
end
