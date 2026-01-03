import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/classic_bluetooth_service.dart';
import '../widgets/device_list_item.dart';
import '../widgets/status_card.dart';
import 'classic_device_screen.dart';

/// 经典蓝牙扫描界面
class ClassicScanScreen extends StatefulWidget {
  const ClassicScanScreen({super.key});

  @override
  State<ClassicScanScreen> createState() => _ClassicScanScreenState();
}

class _ClassicScanScreenState extends State<ClassicScanScreen> {
  final ClassicBluetoothService _btService = ClassicBluetoothService();

  // 状态变量
  bool _isBluetoothEnabled = false;
  bool _isDiscovering = false;
  bool _permissionGranted = false;

  // 设备列表
  List<BluetoothDevice> _bondedDevices = [];
  List<BluetoothDevice> _discoveredDevices = [];

  // 订阅
  StreamSubscription<List<BluetoothDevice>>? _discoveredDevicesSubscription;
  StreamSubscription<bool>? _isDiscoveringSubscription;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final granted = await _requestPermissions();
    if (granted) {
      await _checkBluetoothState();
      await _loadBondedDevices();
    }
    _setupSubscriptions();
  }

  /// 请求权限
  Future<bool> _requestPermissions() async {
    // Android 12+ 需要的权限
    final permissions = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ];

    // 请求权限
    final statuses = await permissions.request();

    // 检查关键权限是否授予 (granted 或 limited 都算通过)
    bool checkPermission(PermissionStatus? status) {
      if (status == null) return true; // 权限不适用于此平台
      return status.isGranted || status.isLimited;
    }

    final scanGranted = checkPermission(statuses[Permission.bluetoothScan]);
    final connectGranted = checkPermission(
      statuses[Permission.bluetoothConnect],
    );
    final allGranted = scanGranted && connectGranted;

    if (mounted) {
      setState(() {
        _permissionGranted = allGranted;
      });
    }

    return allGranted;
  }

  /// 检查蓝牙状态
  Future<void> _checkBluetoothState() async {
    final isEnabled = await _btService.isEnabled;
    setState(() {
      _isBluetoothEnabled = isEnabled;
    });
  }

  /// 加载已配对设备
  Future<void> _loadBondedDevices() async {
    final devices = await _btService.getBondedDevices();
    setState(() {
      _bondedDevices = devices;
    });
  }

  /// 设置订阅
  void _setupSubscriptions() {
    _discoveredDevicesSubscription = _btService.discoveredDevices.listen((
      devices,
    ) {
      setState(() {
        _discoveredDevices = devices;
      });
    });

    _isDiscoveringSubscription = _btService.isDiscovering.listen((
      isDiscovering,
    ) {
      setState(() {
        _isDiscovering = isDiscovering;
      });
    });
  }

  /// 开始/停止发现设备
  Future<void> _toggleDiscovery() async {
    if (_isDiscovering) {
      await _btService.cancelDiscovery();
    } else {
      await _btService.startDiscovery();
    }
  }

  /// 开启蓝牙
  Future<void> _enableBluetooth() async {
    final result = await _btService.requestEnable();
    if (result) {
      await _checkBluetoothState();
      await _loadBondedDevices();
    }
  }

  /// 连接设备
  Future<void> _connectDevice(BluetoothDevice device) async {
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在连接...'),
          ],
        ),
      ),
    );

    final success = await _btService.connect(device);

    // 关闭加载对话框
    if (mounted) {
      Navigator.pop(context);
    }

    if (success && mounted) {
      // 跳转到设备详情页
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClassicDeviceScreen(device: device),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('连接 ${device.name ?? "设备"} 失败')));
    }
  }

  /// 配对设备
  Future<void> _bondDevice(BluetoothDevice device) async {
    final result = await _btService.bondDevice(device);
    if (result) {
      await _loadBondedDevices();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已配对 ${device.name ?? "设备"}')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('配对 ${device.name ?? "设备"} 失败')));
    }
  }

  /// 取消配对
  Future<void> _removeBond(BluetoothDevice device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消配对'),
        content: Text('确定要取消与 ${device.name ?? "设备"} 的配对吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _btService.removeBond(device);
      if (result) {
        await _loadBondedDevices();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已取消与 ${device.name ?? "设备"} 的配对')),
        );
      }
    }
  }

  @override
  void dispose() {
    _discoveredDevicesSubscription?.cancel();
    _isDiscoveringSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('经典蓝牙'),
        actions: [
          // 刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _checkBluetoothState();
              await _loadBondedDevices();
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 权限未授予
    if (!_permissionGranted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('需要蓝牙权限'),
            const SizedBox(height: 8),
            const Text(
              '请授予蓝牙权限以扫描设备',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _requestPermissions,
              child: const Text('请求权限'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => openAppSettings(),
              child: const Text('打开系统设置'),
            ),
          ],
        ),
      );
    }

    // 蓝牙未开启
    if (!_isBluetoothEnabled) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('蓝牙未开启'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _enableBluetooth,
              child: const Text('开启蓝牙'),
            ),
          ],
        ),
      );
    }

    // 设备列表
    return Column(
      children: [
        // 状态信息
        _buildStatusCard(),

        // 扫描按钮
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isDiscovering ? null : _toggleDiscovery,
                  icon: _isDiscovering
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(_isDiscovering ? '扫描中...' : '开始扫描'),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _isDiscovering ? _toggleDiscovery : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[100],
                ),
                child: const Text('停止'),
              ),
            ],
          ),
        ),

        // 列表区域
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadBondedDevices();
            },
            child: ListView(
              children: [
                // 已配对设备
                if (_bondedDevices.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.link, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          '已配对设备 (${_bondedDevices.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._bondedDevices.map(
                    (device) => _buildDeviceCard(device, isBonded: true),
                  ),
                ],

                // 发现的设备
                if (_discoveredDevices.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.radar, size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          '发现的设备 (${_discoveredDevices.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._discoveredDevices.map(
                    (device) => _buildDeviceCard(device, isBonded: false),
                  ),
                ],

                // 空状态提示
                if (_bondedDevices.isEmpty && _discoveredDevices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(48),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bluetooth_searching,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '点击"开始扫描"搜索附近设备',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 底部留白
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建状态卡片
  Widget _buildStatusCard() {
    return StatusCard(
      title: '状态信息',
      children: [
        StatusRow(
          label: '蓝牙状态',
          value: _isBluetoothEnabled ? '已开启' : '未开启',
          color: _isBluetoothEnabled ? Colors.green : Colors.grey,
          icon: _isBluetoothEnabled
              ? Icons.bluetooth
              : Icons.bluetooth_disabled,
        ),
        StatusRow(
          label: '扫描状态',
          value: _isDiscovering ? '扫描中' : '未扫描',
          color: _isDiscovering ? Colors.orange : Colors.grey,
          icon: _isDiscovering ? Icons.radar : Icons.search_off,
        ),
        StatusRow(
          label: '设备数量',
          value:
              '配对: ${_bondedDevices.length} / 发现: ${_discoveredDevices.length}',
          color: Colors.blue,
        ),
      ],
    );
  }

  /// 构建设备卡片
  Widget _buildDeviceCard(BluetoothDevice device, {required bool isBonded}) {
    return DeviceListItem(
      name: device.name ?? '未知设备',
      id: device.address,
      leading: CircleAvatar(
        backgroundColor: isBonded ? Colors.blue : Colors.grey,
        child: Text(device.type.icon, style: const TextStyle(fontSize: 20)),
      ),
      subtitle: Text(
        '${device.type.displayName} · ${device.bondState.displayName}',
        style: TextStyle(
          color: isBonded ? Colors.blue : Colors.grey,
          fontSize: 12,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isBonded)
            IconButton(
              icon: const Icon(Icons.link),
              tooltip: '配对',
              onPressed: () => _bondDevice(device),
            ),
          if (isBonded)
            IconButton(
              icon: const Icon(Icons.link_off),
              tooltip: '取消配对',
              onPressed: () => _removeBond(device),
            ),
          IconButton(
            icon: const Icon(Icons.bluetooth_connected),
            tooltip: '连接',
            onPressed: () => _connectDevice(device),
          ),
        ],
      ),
    );
  }
}
