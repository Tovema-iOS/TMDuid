#
# Be sure to run `pod lib lint TMDuid.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "TMDuid"
  s.version          = "1.0"
  s.summary          = "A short description of TMDuid."

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!
  s.description      = "用户唯一标识库"

  s.homepage         = "https://github.com/Tovema-iOS/TMDuid"
  # s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = 'MIT'
  s.author           = { 'CodingPub' => 'lxb_0605@qq.com' }
  s.source           = { :git => "https://github.com/Tovema-iOS/TMDuid.git", :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.platform     = :ios, '8.0'
  s.requires_arc = false

  s.source_files = 'Pod/Classes/**/*'
  s.public_header_files = 'Pod/Classes/*.h'


# #pod本地库检查
  # pod lib lint ../TMDuid.podspec  --verbose --allow-warnings --use-libraries --sources=flspecs --no-clean

end
