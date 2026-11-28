# ruflet_native on iOS: a resource-only pod. The plugin has no Objective-C,
# Swift or C source and links no framework: its Dart code opens each system
# framework with dlopen on first use and calls it over the Objective-C
# runtime (package:objective_c). The pod exists only to ship the privacy
# manifest for the APIs that Dart code calls.
Pod::Spec.new do |s|
  s.name             = 'ruflet_native'
  s.version          = '0.1.0'
  s.summary          = 'Ruflet native services over FFI (privacy manifest only).'
  s.description      = 'Resource-only pod: PrivacyInfo.xcprivacy for ruflet_native.'
  s.homepage         = 'https://github.com/AdamMusa/ruflet-engine'
  s.license          = { :type => 'Apache-2.0', :file => '../LICENSE' }
  s.author           = { 'Ruflet' => 'https://github.com/AdamMusa/ruflet-engine' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '16.0' # the Ruflet template's Podfile platform
  s.resource_bundles = { 'ruflet_native_privacy' => ['Resources/PrivacyInfo.xcprivacy'] }
end
