#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'file_share_intent'
  s.version          = '3.0.3'
  s.summary          = 'A flutter plugin that enables flutter apps to receive sharing photos from other apps.'
  s.description      = <<-DESC
A flutter plugin that enables flutter apps to receive sharing photos from other apps.
                       DESC
  s.homepage         = 'https://waltertay.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Walter' => 'walter@bookslice.app' }
  s.source           = { :path => '.' }
  
  # Only include the Flutter plugin files (exclude Share Extension classes)
  # Adjust this pattern based on which files should stay here vs move to Models
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  
  # Exclude the Share Extension classes that are now in Models/
  s.exclude_files = [
    'Classes/RSIBaseShareViewController.swift',
    'Classes/RSIShareViewController.swift'
  ]
  
  s.dependency 'Flutter'

  s.ios.deployment_target = '12.0'
  s.swift_version = '5.0'
  s.frameworks = 'MobileCoreServices'
  
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end