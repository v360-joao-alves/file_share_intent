Pod::Spec.new do |s|
  s.name             = 'file_share_intent_models'
  s.version          = '3.0.3'
  s.summary          = 'Share Extension base classes for file_share_intent (no Flutter dependency)'
  s.description      = <<-DESC
Contains Share Extension view controllers that can be used in iOS Share Extensions
without requiring Flutter framework. This allows Share Extensions to compile
properly since they cannot link against Flutter.
                       DESC
  s.homepage         = 'https://waltertay.com'
  s.license          = { :file => '../../LICENSE' }
  s.author           = { 'Walter' => 'walter@bookslice.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Sources/**/*.swift'
  
  s.ios.deployment_target = '12.0'
  s.swift_version    = '5.0'
  
  s.frameworks = 'UIKit', 'Social', 'MobileCoreServices', 'UniformTypeIdentifiers'
  
  # CRITICAL: No Flutter dependency!
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'APPLICATION_EXTENSION_API_ONLY' => 'YES'
  }
end