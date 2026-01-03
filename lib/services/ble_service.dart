import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// 蓝牙服务类 - 封装 flutter_blue_plus 的常用操作
class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  // 扫描结果流
  final _scanResultsController = StreamController<List<ScanResult>>.broadcast();
  Stream<List<ScanResult>> get scanResults => _scanResultsController.stream;

  // 当前连接的设备
  BluetoothDevice? _connectedDevice;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  // 连接状态流
  final _connectionStateController = StreamController<BluetoothConnectionState>.broadcast();
  Stream<BluetoothConnectionState> get connectionState => _connectionStateController.stream;

  // 接收数据流
  final _receivedDataController = StreamController<List<int>>.broadcast();
  Stream<List<int>> get receivedData => _receivedDataController.stream;

  // 设备服务和特征
  List<BluetoothService> _services = [];
  List<BluetoothService> get services => _services;

  // 用于写入的特征
  BluetoothCharacteristic? _writeCharacteristic;
  // 用于读取/通知的特征
  BluetoothCharacteristic? _notifyCharacteristic;

  StreamSubscription? _connectionSubscription;
  StreamSubscription? _scanSubscription;

  /// 请求蓝牙权限 (使用 flutter_blue_plus 内置方法)
  Future<bool> requestPermissions() async {
    // 检查是否支持蓝牙
    if (await FlutterBluePlus.isSupported == false) {
      return false;
    }

    // Android 需要请求权限
    if (Platform.isAndroid) {
      // 检查蓝牙是否开启，如果没有开启会自动请求开启
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        // 尝试开启蓝牙
        try {
          await FlutterBluePlus.turnOn();
        } catch (e) {
          print('无法开启蓝牙: $e');
        }
      }
    }

    // 检查最终状态
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  /// 检查蓝牙是否开启
  Future<bool> isBluetoothOn() async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  /// 开始扫描设备
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    // 先停止之前的扫描
    await stopScan();

    // 清空之前的结果
    _scanResultsController.add([]);

    // 订阅扫描结果
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      _scanResultsController.add(results);
    });

    // 开始扫描
    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidUsesFineLocation: true,
    );
  }

  /// 停止扫描
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  /// 连接设备
  Future<bool> connect(BluetoothDevice device, {Duration timeout = const Duration(seconds: 15)}) async {
    try {
      // 先断开之前的连接
      await disconnect();

      // 连接设备 (license: 个人/非营利/教育/小型组织可使用 free)
      await device.connect(
        timeout: timeout,
        license: License.free,
      );

      _connectedDevice = device;

      // 监听连接状态
      _connectionSubscription = device.connectionState.listen((state) {
        _connectionStateController.add(state);
        if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _services = [];
          _writeCharacteristic = null;
          _notifyCharacteristic = null;
        }
      });

      // 发现服务
      await discoverServices();

      return true;
    } catch (e) {
      print('连接失败: $e');
      return false;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
    }

    _services = [];
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
    _connectionStateController.add(BluetoothConnectionState.disconnected);
  }

  /// 发现服务
  Future<void> discoverServices() async {
    if (_connectedDevice == null) return;

    _services = await _connectedDevice!.discoverServices();

    // 自动查找可用的写入和通知特征
    for (var service in _services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
          _writeCharacteristic ??= characteristic;
        }
        if (characteristic.properties.notify || characteristic.properties.indicate) {
          _notifyCharacteristic ??= characteristic;
        }
      }
    }
  }

  /// 设置写入特征
  void setWriteCharacteristic(BluetoothCharacteristic characteristic) {
    _writeCharacteristic = characteristic;
  }

  /// 设置通知特征
  void setNotifyCharacteristic(BluetoothCharacteristic characteristic) {
    _notifyCharacteristic = characteristic;
  }

  /// 启用通知
  Future<bool> enableNotifications(BluetoothCharacteristic? characteristic) async {
    final char = characteristic ?? _notifyCharacteristic;
    if (char == null) return false;

    try {
      await char.setNotifyValue(true);

      // 订阅通知数据
      char.onValueReceived.listen((value) {
        _receivedDataController.add(value);
      });

      return true;
    } catch (e) {
      print('启用通知失败: $e');
      return false;
    }
  }

  /// 禁用通知
  Future<bool> disableNotifications(BluetoothCharacteristic? characteristic) async {
    final char = characteristic ?? _notifyCharacteristic;
    if (char == null) return false;

    try {
      await char.setNotifyValue(false);
      return true;
    } catch (e) {
      print('禁用通知失败: $e');
      return false;
    }
  }

  /// 写入数据
  Future<bool> writeData(List<int> data, {BluetoothCharacteristic? characteristic, bool withResponse = true}) async {
    final char = characteristic ?? _writeCharacteristic;
    if (char == null) {
      print('没有可用的写入特征');
      return false;
    }

    try {
      await char.write(
        data,
        withoutResponse: !withResponse,
      );
      return true;
    } catch (e) {
      print('写入数据失败: $e');
      return false;
    }
  }

  /// 写入字符串
  Future<bool> writeString(String text, {BluetoothCharacteristic? characteristic, bool withResponse = true}) async {
    final data = Uint8List.fromList(text.codeUnits);
    return writeData(data.toList(), characteristic: characteristic, withResponse: withResponse);
  }

  /// 读取数据
  Future<List<int>?> readData(BluetoothCharacteristic characteristic) async {
    try {
      return await characteristic.read();
    } catch (e) {
      print('读取数据失败: $e');
      return null;
    }
  }

  /// 获取设备信号强度
  Future<int?> readRssi() async {
    if (_connectedDevice == null) return null;
    try {
      return await _connectedDevice!.readRssi();
    } catch (e) {
      print('读取 RSSI 失败: $e');
      return null;
    }
  }

  /// 请求 MTU
  Future<int?> requestMtu(int mtu) async {
    if (_connectedDevice == null) return null;
    try {
      return await _connectedDevice!.requestMtu(mtu);
    } catch (e) {
      print('请求 MTU 失败: $e');
      return null;
    }
  }

  /// 释放资源
  void dispose() {
    _scanResultsController.close();
    _connectionStateController.close();
    _receivedDataController.close();
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
  }
}
