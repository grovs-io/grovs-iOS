Pod::Spec.new do |s|
  s.name         = 'Grovs'
  s.version      = '1.4'
  s.summary      = 'Grovs is a powerful SDK that enables deep linking and universal linking within your iOS applications.'
  s.homepage     = 'https://grovs.io'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'Grovs' => 'support@grovs.io' }
  s.source       = { :git => 'https://github.com/grovs-io/grovs-iOS.git', :tag => s.version.to_s }
  s.swift_version = '5.0'
  s.module_name  = 'Grovs' 

  s.source_files = 'Sources/**/*.swift'  # Adjust this path to match your package structure

  s.platform     = :ios
  s.ios.deployment_target = "13.0"
  s.swift_version = '5.0'
end
