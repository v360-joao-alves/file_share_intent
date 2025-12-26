Pod::Spec.new do |s|
  s.name             = 'file_share_intent_models'
  s.version          = '3.0.3'
  s.summary          = 'Share Extension models for file_share_intent'
  s.description      = <<-DESC
Pure Swift code used by the Share Extension.
No Flutter dependency.
                       DESC

  s.homepage         = 'https://waltertay.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Walter' => 'walter@bookslice.app' }
  s.source           = { :path => '.' }

  s.source_files = [
    'Classes/RSIBaseShareViewController.swift',
    'Classes/RSIShareViewController.swift'
  ]

  s.ios.deployment_target = '12.0'
  s.swift_version = '5.0'

  s.frameworks = 'MobileCoreServices', 'UniformTypeIdentifiers'
end
