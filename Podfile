platform :ios, :deployment_target => '4.3'

xcodeproj 'HTStateAwareRasterImageView'

pod 'MAObjCRuntime'

pod 'MSCachedAsyncViewDrawing', :podspec => './MSCachedAsyncViewDrawing.podspec'

post_install do |installer|
  installer.target_installers.each do |target_installer|
    target_installer.target.build_configurations.each do |config|
      config.build_settings['GCC_WARN_ABOUT_MISSING_PROTOTYPES'] = 'NO'
      config.build_settings['GCC_THUMB_SUPPORT'] = 'NO'
    end
  end
end
