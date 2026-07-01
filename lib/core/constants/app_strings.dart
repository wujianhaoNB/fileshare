/// 用户界面文字（中文）。
class AppStrings {
  AppStrings._();

  // App
  static const String appName = '文件快传';
  static const String appTagline = '快速、安全的文件传输';

  // Home
  static const String onlineDevices = '在线设备';
  static const String pairedDevices = '已配对设备';
  static const String noDevicesFound = '未发现设备';
  static const String searchingDevices = '正在搜索设备...';
  static const String scanQR = '扫一扫';
  static const String showMyQR = '我的二维码';
  static const String refreshDevices = '刷新';

  // Transfer
  static const String send = '发送';
  static const String receive = '接收';
  static const String sending = '发送中';
  static const String receiving = '接收中';
  static const String queued = '排队中';
  static const String completed = '已完成';
  static const String failed = '失败';
  static const String cancelled = '已取消';
  static const String paused = '已暂停';
  static const String resume = '继续';
  static const String cancel = '取消';
  static const String retry = '重试';
  static const String openFile = '打开';
  static const String shareFile = '分享';

  // Pairing
  static const String pairDevice = '配对设备';
  static const String pairingRequest = '配对请求';
  static const String confirmPairing = '确认配对';
  static const String pairingCodePrompt = '两台设备上的验证码是否一致？';
  static const String deviceNotPaired = '设备未配对';
  static const String unpairDevice = '取消配对';
  static const String pairedSuccessfully = '配对成功';

  // Settings
  static const String settings = '设置';
  static const String deviceName = '设备名称';
  static const String downloadPath = '下载路径';
  static const String transferPort = '传输端口';
  static const String encryption = '加密传输';
  static const String clearHistory = '清除记录';
  static const String about = '关于';

  // Errors
  static const String connectionFailed = '连接失败';
  static const String transferFailed = '传输失败';
  static const String fileNotFound = '文件未找到';
  static const String storageFull = '存储空间不足';
  static const String permissionDenied = '权限被拒绝';
  static const String deviceUnreachable = '设备不可达';
  static const String hashMismatch = '文件校验失败';
  static const String networkError = '网络错误';
  static const String unknownError = '发生未知错误';

  // Permissions
  static const String storagePermission = '需要存储权限来保存文件';
  static const String cameraPermission = '需要相机权限来扫描二维码';
  static const String locationPermission = '需要位置权限来查找附近设备';
  static const String bluetoothPermission = '需要蓝牙权限来发现设备';
  static const String notificationPermission = '需要通知权限来显示传输进度';

  // Bluetooth warning
  static const String bluetoothSlowWarning =
      '蓝牙传输大文件较慢。建议连接到同一 Wi-Fi 网络以获得更快速度。';
}
