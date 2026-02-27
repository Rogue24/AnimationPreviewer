# Uncomment the next line to define a global platform for your project
platform :ios, '15.0'

target 'AnimationPreviewer' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  
  # 升级了pb的SVGAPlayer源仓库（fork）
  pod 'SVGAPlayer', :git => 'https://github.com/Rogue24/SVGAPlayer-iOS.git', :tag => '2.5.8'
  
  # 封装并优化后的SVGA播放器
  pod 'SVGAPlayer_Optimized', :git => 'https://github.com/Rogue24/SVGAPlayer_Optimized.git', :tag => '0.1.4'
  
  pod 'SnapKit'
  
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      end
    end
  end

end
