# WechatSDK


1. 下载SDK：https://developers.weixin.qq.com/doc/oplatform/Mobile_App/Downloads/iOS_Resource.html

2. 获取checksum：

   ```
   swift package compute-checksum /替换路径/OpenSDK2.0.5_NoPay.zip
   ```

   

- Wrap `WeChatOpenSDK-XCFramework.xcframework`2.0.5 and make it easy to use with `Swift Package Manager`.

- You can import target: WechatOC in Objective-C or just Target: WechatSwift in Swift without having to create a bridge file again

  

如果发生提示微信MinimumOSVersion：

```
# 脚本功能: 查找并修改通过SPM引入的WechatOpenSDK.framework的MinimumOSVersion，
# 使其与主App的部署目标版本(IPHONEOS_DEPLOYMENT_TARGET)保持一致。
if [ "$ACTION" != "install" ]; then
  echo "Info: Skip script (only run during Archive)"
  exit 0
fi
# 获取主App的部署目标版本，例如 '15.0'
TARGET_SDK_VERSION=${IPHONEOS_DEPLOYMENT_TARGET}

# 在最终App的Frameworks文件夹中定位WechatOpenSDK.framework
# 当通过SPM集成时，Xcode会将其放在这个标准路径下
FRAMEWORK_PATH="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/WechatOpenSDK.framework"

# 检查该framework是否存在
if [ -d "$FRAMEWORK_PATH" ]; then
  echo "Info: Found WechatOpenSDK.framework at $FRAMEWORK_PATH"
  
  # 使用PlistBuddy工具修改Info.plist文件中的MinimumOSVersion键值
  /usr/libexec/PlistBuddy -c "Set :MinimumOSVersion $TARGET_SDK_VERSION" "$FRAMEWORK_PATH/Info.plist"
  
  echo "Success: Set MinimumOSVersion to $TARGET_SDK_VERSION for WechatOpenSDK.framework"
else
  # 如果找不到，打印一个警告，这在某些配置下可能是正常的（例如Mac编译）
  echo "Warning: WechatOpenSDK.framework not found in standard path. The script did not run."
fi
```

