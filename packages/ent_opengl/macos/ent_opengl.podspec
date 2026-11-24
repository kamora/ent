Pod::Spec.new do |s|
	s.name             = 'ent_opengl'
	s.version          = '0.1.0'
	s.summary          = 'The OpenGL ES renderer of Ent Engine: the textures Flutter shows its frames in.'
	s.homepage         = 'https://github.com/kamora/ent'
	s.license          = { :type => 'MIT', :file => '../LICENSE' }
	s.author           = { 'KAMORA Ltd.' => 'https://github.com/kamora' }
	s.source           = { :path => '.' }
	s.source_files     = 'ent_opengl/Sources/ent_opengl/**/*.swift'
	s.dependency 'FlutterMacOS'
	s.platform = :osx, '10.15'
	s.swift_version = '5.0'
end
