#
#  Be sure to run `pod spec lint Swirc.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
Pod::Spec.new do |s|
  s.name         = "Swirc"
  s.version      = "0.0.1"
  s.summary      = "A framework for communicating with IRC servers."

  s.description  = <<-DESC
Swirc, or Swift IRC, is a simple framework for connecting and communicating with IRC servers.
                   DESC

  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "James Shephard" => "james@jshephard.net" }
  s.homepage     = 'https://github.com/jshephard/swirc'

  s.platform     = :osx, "10.11"
  s.source       = { :git => "http://github.com/jshephard/swirc.git" }
  s.source_files  = "Swirc/**/*"
  s.dependency 'CocoaAsyncSocket'
  s.dependency 'SwiftyBeaver'
end
