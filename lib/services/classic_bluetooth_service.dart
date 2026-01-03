import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

/// 经典蓝牙服务 - 支持 SPP 串口通信
/// 用于蓝牙耳机、蓝牙串口模块 (HC-05/HC-06) 等经典蓝牙设备
class ClassicBluetoothService {
  // 单例模式
  static final ClassicBluetoothService _instance =
      ClassicBluetoothService._internal();
  factory ClassicBluetoothService() => _instance;
  ClassicBluetoothService._internal();

  // Flutter Bluetooth Serial 实例
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;

  // 当前连接
  BluetoothConnection? _connection;

  // 已发现的设备列表
  final List<BluetoothDevice> _discoveredDevices = [];

  // Stream Controllers
  final _discoveredDevicesController =
      StreamController<List<BluetoothDevice>>.broadcast();
  final _connectionStateController =
      StreamController<BluetoothConnectionState>.broadcast();
  final _receivedDataController = StreamController<Uint8List>.broadcast();
  final _isDiscoveringController = StreamController<bool>.broadcast();

  // Streams
  Stream<List<BluetoothDevice>> get discoveredDevices =>
      _discoveredDevicesController.stream;
  Stream<BluetoothConnectionState> get connectionState =>
      _connectionStateController.stream;
  Stream<Uint8List> get receivedData => _receivedDataController.stream;
  Stream<bool> get isDiscovering => _isDiscoveringController.stream;

  // 当前连接的设备
  BluetoothDevice? _connectedDevice;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  // 是否正在扫描
  bool _isCurrentlyDiscovering = false;
  bool get isCurrentlyDiscovering => _isCurrentlyDiscovering;

  // 数据接收订阅
  StreamSubscription<Uint8List>? _dataSubscription;

  /// 检查蓝牙是否可用
  Future<bool> get isAvailable async {
    return await _bluetooth.isAvailable ?? false;
  }

  /// 检查蓝牙是否开启
  Future<bool> get isEnabled async {
    return await _bluetooth.isEnabled ?? false;
  }

  /// 获取蓝牙状态
  Future<BluetoothState> get state async {
    return await _bluetooth.state;
  }

  /// 请求开启蓝牙
  Future<bool> requestEnable() async {
    try {
      return await _bluetooth.requestEnable() ?? false;
    } catch (e) {
      print('请求开启蓝牙失败: $e');
      return false;
    }
  }

  /// 请求关闭蓝牙
  Future<bool> requestDisable() async {
    try {
      return await _bluetooth.requestDisable() ?? false;
    } catch (e) {
      print('请求关闭蓝牙失败: $e');
      return false;
    }
  }

  /// 获取已配对的设备列表
  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      return await _bluetooth.getBondedDevices();
    } catch (e) {
      print('获取已配对设备失败: $e');
      return [];
    }
  }

  /// 开始发现设备
  Future<void> startDiscovery() async {
    if (_isCurrentlyDiscovering) {
      return;
    }

    _isCurrentlyDiscovering = true;
    _isDiscoveringController.add(true);
    _discoveredDevices.clear();
    _discoveredDevicesController.add([]);

    try {
      _bluetooth.startDiscovery().listen(
        (result) {
          // 避免重复添加
          final existingIndex = _discoveredDevices
              .indexWhere((d) => d.address == result.device.address);
          if (existingIndex == -1) {
            _discoveredDevices.add(result.device);
          } else {
            _discoveredDevices[existingIndex] = result.device;
          }
          _discoveredDevicesController.add(List.from(_discoveredDevices));
        },
        onDone: () {
          _isCurrentlyDiscovering = false;
          _isDiscoveringController.add(false);
        },
        onError: (error) {
          print('发现设备错误: $error');
          _isCurrentlyDiscovering = false;
          _isDiscoveringController.add(false);
        },
      );
    } catch (e) {
      print('开始发现设备失败: $e');
      _isCurrentlyDiscovering = false;
      _isDiscoveringController.add(false);
    }
  }

  /// 停止发现设备
  Future<void> cancelDiscovery() async {
    try {
      await _bluetooth.cancelDiscovery();
      _isCurrentlyDiscovering = false;
      _isDiscoveringController.add(false);
    } catch (e) {
      print('停止发现设备失败: $e');
    }
  }

  /// 连接到设备 (SPP)
  Future<bool> connect(BluetoothDevice device) async {
    try {
      // 如果已有连接，先断开
      await disconnect();

      _connectionStateController.add(BluetoothConnectionState.connecting);

      // 尝试建立 SPP 连接
      _connection = await BluetoothConnection.toAddress(device.address);

      if (_connection != null && _connection!.isConnected) {
        _connectedDevice = device;
        _connectionStateController.add(BluetoothConnectionState.connected);

        // 监听接收到的数据
        _dataSubscription = _connection!.input?.listen(
          (data) {
            _receivedDataController.add(data);
          },
          onDone: () {
            _handleDisconnection();
          },
          onError: (error) {
            print('数据接收错误: $error');
            _handleDisconnection();
          },
        );

        return true;
      } else {
        _connectionStateController.add(BluetoothConnectionState.disconnected);
        return false;
      }
    } catch (e) {
      print('连接失败: $e');
      _connectionStateController.add(BluetoothConnectionState.disconnected);
      return false;
    }
  }

  /// 处理断开连接
  void _handleDisconnection() {
    _connectedDevice = null;
    _connectionStateController.add(BluetoothConnectionState.disconnected);
  }

  /// 断开连接
  Future<void> disconnect() async {
    try {
      await _dataSubscription?.cancel();
      _dataSubscription = null;

      await _connection?.close();
      _connection = null;

      _connectedDevice = null;
      _connectionStateController.add(BluetoothConnectionState.disconnected);
    } catch (e) {
      print('断开连接失败: $e');
    }
  }

  /// 检查是否已连接
  bool get isConnected => _connection?.isConnected ?? false;

  /// 发送数据 (字节数组)
  Future<bool> sendData(Uint8List data) async {
    if (_connection == null || !_connection!.isConnected) {
      print('未连接，无法发送数据');
      return false;
    }

    try {
      _connection!.output.add(data);
      await _connection!.output.allSent;
      return true;
    } catch (e) {
      print('发送数据失败: $e');
      return false;
    }
  }

  /// 发送字符串
  Future<bool> sendString(String text) async {
    return sendData(Uint8List.fromList(utf8.encode(text)));
  }

  /// 发送字符串并添加换行符
  Future<bool> sendLine(String text) async {
    return sendString('$text\r\n');
  }

  /// 配对设备
  Future<bool> bondDevice(BluetoothDevice device) async {
    try {
      final result = await _bluetooth.bondDeviceAtAddress(device.address);
      return result ?? false;
    } catch (e) {
      print('配对失败: $e');
      return false;
    }
  }

  /// 取消配对
  Future<bool> removeBond(BluetoothDevice device) async {
    try {
      final result =
          await _bluetooth.removeDeviceBondWithAddress(device.address);
      return result ?? false;
    } catch (e) {
      print('取消配对失败: $e');
      return false;
    }
  }

  /// 设置设备可被发现
  Future<int?> requestDiscoverable(int duration) async {
    try {
      return await _bluetooth.requestDiscoverable(duration);
    } catch (e) {
      print('请求可发现模式失败: $e');
      return null;
    }
  }

  /// 获取本机蓝牙名称
  Future<String?> get name => _bluetooth.name;

  /// 获取本机蓝牙地址
  Future<String?> get address => _bluetooth.address;

  /// 设置本机蓝牙名称
  Future<bool> changeName(String name) async {
    try {
      return await _bluetooth.changeName(name) ?? false;
    } catch (e) {
      print('修改蓝牙名称失败: $e');
      return false;
    }
  }

  /// 释放资源
  void dispose() {
    _dataSubscription?.cancel();
    _connection?.close();

    _discoveredDevicesController.close();
    _connectionStateController.close();
    _receivedDataController.close();
    _isDiscoveringController.close();
  }
}

/// 蓝牙连接状态枚举
enum BluetoothConnectionState {
  disconnected,
  connecting,
  connected,
}

/// 设备类型扩展
extension BluetoothDeviceTypeExtension on BluetoothDeviceType {
  String get displayName {
    switch (this) {
      case BluetoothDeviceType.classic:
        return '经典蓝牙';
      case BluetoothDeviceType.le:
        return '低功耗蓝牙 (BLE)';
      case BluetoothDeviceType.dual:
        return '双模蓝牙';
      case BluetoothDeviceType.unknown:
      default:
        return '未知类型';
    }
  }

  String get icon {
    switch (this) {
      case BluetoothDeviceType.classic:
        return '🎧';
      case BluetoothDeviceType.le:
        return '📱';
      case BluetoothDeviceType.dual:
        return '🔗';
      case BluetoothDeviceType.unknown:
      default:
        return '❓';
    }
  }
}

/// 蓝牙绑定状态扩展
extension BluetoothBondStateExtension on BluetoothBondState {
  String get displayName {
    switch (this) {
      case BluetoothBondState.bonded:
        return '已配对';
      case BluetoothBondState.bonding:
        return '配对中';
      case BluetoothBondState.none:
      default:
        return '未配对';
    }
  }
}
