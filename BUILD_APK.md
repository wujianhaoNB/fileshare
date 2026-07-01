# FileShare APK 构建说明

## 环境变量 (永久设置)

在系统环境变量中添加：

```
JAVA_HOME=D:\jdk17
ANDROID_HOME=D:\Android
ANDROID_SDK_ROOT=D:\Android
GRADLE_USER_HOME=D:\gradle
PUB_CACHE=D:\pub-cache
```

## 构建命令

```powershell
cd D:\fileshare
flutter build apk --release
```

输出: build\app\outputs\flutter-apk\app-release.apk
