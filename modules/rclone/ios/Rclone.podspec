Pod::Spec.new do |s|
  s.name = 'Rclone'
  s.version = '1.0.0'
  s.summary = 'Expo bridge for the embedded rclone engine'
  s.description = 'Local Expo module that exposes the rclone RPC interface.'
  s.author = 'Fibu'
  s.homepage = 'https://github.com/PeWieser/fibu'
  s.source = { git: '' }
  s.platforms = { ios: '16.4' }
  s.swift_version = '5.9'
  s.static_framework = true

  s.dependency 'ExpoModulesCore'
  s.source_files = '**/*.{h,m,mm,swift,hpp,cpp}'
end
