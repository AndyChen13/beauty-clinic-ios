# User Interface

## Privacy Policy URL for App Store

https://github.com/YOUR_USERNAME/beauty-clinic-ios/blob/main/docs/PRIVACY_POLICY.md

## Required Permissions

- **Camera**: For customer photos (optional)
- **Photos**: For uploading training materials
- **Notifications**: For appointment reminders

Add these to Info.plist:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>上传客户照片和培训资料</string>
<key>NSCameraUsageDescription</key>
<string>拍摄客户照片用于档案记录</string>
<key>UNUserNotificationCenterDelegate</key>
<string>Appdelegate</string>
```

## App Icon

Replace the default icon in `Assets.xcassets/AppIcon.appiconset/` with your brand icon.