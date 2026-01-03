import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/ble_service.dart';
import '../widgets/device_list_item.dart';
import '../widgets/status_card.dart';
import 'device_detail_screen.dart';

/// 设备扫描页面 - 展示蓝牙扫描功能
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final BleService _bleService = BleService();

  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  bool _bluetoothOn = false;
  bool _permissionGranted = false;

  StreamSubscription? _scanResultsSubscription;
  StreamSubscription? _isScanningSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // 请求权限
    _permissionGranted = await _bleService.requestPermissions();

    // 检查蓝牙状态
    _bluetoothOn = await _bleService.isBluetoothOn();

    // 监听扫描结果
    _scanResultsSubscription = _bleService.scanResults.listen((results) {
      setState(() {
        _scanResults = results;
      });
    });

    // 监听扫描状态
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((isScanning) {
      setState(() {
        _isScanning = isScanning;
      });
    });

    // 监听蓝牙状态变化
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (!mounted) return;
      setState(() {
        _bluetoothOn = state == BluetoothAdapterState.on;
      });
    });

    setState(() {});
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    // 每次扫描前都重新检查蓝牙状态
    _bluetoothOn = await _bleService.isBluetoothOn();
    setState(() {});

    if (!_bluetoothOn) {
      _showMessage('请先开启蓝牙');
      // 尝试请求开启蓝牙
      _permissionGranted = await _bleService.requestPermissions();
      _bluetoothOn = await _bleService.isBluetoothOn();
      setState(() {});
      if (!_bluetoothOn) {
        return;
      }
    }

    // 尝试开始扫描，flutter_blue_plus 会自动请求必要权限
    try {
      await _bleService.startScan();
      _permissionGranted = true;
      setState(() {});
    } catch (e) {
      _permissionGranted = false;
      setState(() {});
      _showMessage('扫描失败: $e');
    }
  }

  Future<void> _stopScan() async {
    await _bleService.stopScan();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    _showMessage('正在连接 ${device.platformName}...');

    await _stopScan();

    final success = await _bleService.connect(device);

    if (success) {
      _showMessage('连接成功!');
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DeviceDetailScreen(device: device),
          ),
        );
      }
    } else {
      _showMessage('连接失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('蓝牙设备扫描'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // 蓝牙状态指示
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(
              Icons.bluetooth,
              color: _bluetoothOn ? Colors.blue : Colors.grey,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 状态信息卡片
          _buildStatusCard(),

          // 扫描按钮
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? null : _startScan,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isScanning ? '扫描中...' : '开始扫描'),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isScanning ? _stopScan : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[100],
                  ),
                  child: const Text('停止'),
                ),
              ],
            ),
          ),

          // 设备列表
          Expanded(
            child: _scanResults.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth_searching,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '点击"开始扫描"搜索附近设备',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _scanResults.length,
                    itemBuilder: (context, index) {
                      return _buildDeviceCard(_scanResults[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return StatusCard(
      title: '状态信息',
      children: [
        StatusRow(
          label: '蓝牙状态',
          value: _bluetoothOn ? '已开启' : '已关闭',
          color: _bluetoothOn ? Colors.green : Colors.red,
        ),
        StatusRow(
          label: '权限状态',
          value: _permissionGranted ? '已授权' : '未授权',
          color: _permissionGranted ? Colors.green : Colors.red,
        ),
        StatusRow(
          label: '发现设备',
          value: '${_scanResults.length} 个',
          color: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildDeviceCard(ScanResult result) {
    final device = result.device;
    return DeviceListItem(
      name: device.platformName,
      id: device.remoteId.toString(),
      rssi: result.rssi,
      subtitle: result.advertisementData.serviceUuids.isNotEmpty
          ? Text(
              '服务: ${result.advertisementData.serviceUuids.length} 个',
              style: const TextStyle(fontSize: 12),
            )
          : null,
      trailing: ElevatedButton(
        onPressed: () => _connectToDevice(device),
        child: const Text('连接'),
      ),
    );
  }
}
