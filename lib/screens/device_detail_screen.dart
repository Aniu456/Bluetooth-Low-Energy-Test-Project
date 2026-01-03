import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/ble_service.dart';
import 'data_transfer_screen.dart';

/// 设备详情页面 - 展示服务和特征，提供控制功能
class DeviceDetailScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  final BleService _bleService = BleService();

  bool _isConnected = true;
  int? _rssi;
  int? _mtu;

  StreamSubscription? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // 监听连接状态
    _connectionSubscription = _bleService.connectionState.listen((state) {
      setState(() {
        _isConnected = state == BluetoothConnectionState.connected;
      });

      if (!_isConnected && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备已断开连接')),
        );
      }
    });

    // 读取 RSSI
    _rssi = await _bleService.readRssi();

    // 请求更大的 MTU
    _mtu = await _bleService.requestMtu(512);

    setState(() {});
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _disconnect() async {
    await _bleService.disconnect();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _refreshServices() async {
    await _bleService.discoverServices();
    setState(() {});
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.platformName.isNotEmpty ? widget.device.platformName : '设备详情'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _refreshServices,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新服务',
          ),
          IconButton(
            onPressed: _disconnect,
            icon: const Icon(Icons.bluetooth_disabled),
            tooltip: '断开连接',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 设备信息卡片
            _buildDeviceInfoCard(),

            // 快捷操作
            _buildQuickActions(),

            // 服务和特征列表
            _buildServicesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bluetooth_connected, color: _isConnected ? Colors.blue : Colors.grey),
                const SizedBox(width: 8),
                const Text('设备信息', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const Divider(),
            _buildInfoRow('名称', widget.device.platformName.isEmpty ? '未知' : widget.device.platformName),
            _buildInfoRow('ID', widget.device.remoteId.toString()),
            _buildInfoRow('连接状态', _isConnected ? '已连接' : '已断开'),
            if (_rssi != null) _buildInfoRow('信号强度', '$_rssi dBm'),
            if (_mtu != null) _buildInfoRow('MTU', '$_mtu'),
            _buildInfoRow('服务数量', '${_bleService.services.length}'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('快捷操作', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DataTransferScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('数据传输测试'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    _rssi = await _bleService.readRssi();
                    setState(() {});
                    _showMessage('RSSI: $_rssi dBm');
                  },
                  icon: const Icon(Icons.signal_cellular_alt),
                  label: const Text('读取信号'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final mtu = await _bleService.requestMtu(512);
                    setState(() {
                      _mtu = mtu;
                    });
                    _showMessage('MTU: $mtu');
                  },
                  icon: const Icon(Icons.tune),
                  label: const Text('请求 MTU'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesSection() {
    final services = _bleService.services;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('服务和特征', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${services.length} 个服务', style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          if (services.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text('未发现服务', style: TextStyle(color: Colors.grey)),
                ),
              ),
            )
          else
            ...services.map((service) => _buildServiceCard(service)),
        ],
      ),
    );
  }

  Widget _buildServiceCard(BluetoothService service) {
    final uuid = service.uuid.toString();
    final isKnownService = _getServiceName(uuid) != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(
          isKnownService ? Icons.verified : Icons.extension,
          color: isKnownService ? Colors.green : Colors.grey,
        ),
        title: Text(
          _getServiceName(uuid) ?? 'Unknown Service',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          uuid.toUpperCase(),
          style: const TextStyle(fontSize: 10),
        ),
        children: service.characteristics.map((c) => _buildCharacteristicTile(c)).toList(),
      ),
    );
  }

  Widget _buildCharacteristicTile(BluetoothCharacteristic characteristic) {
    final props = characteristic.properties;
    final propList = <String>[];
    if (props.read) propList.add('读');
    if (props.write) propList.add('写');
    if (props.writeWithoutResponse) propList.add('写(无响应)');
    if (props.notify) propList.add('通知');
    if (props.indicate) propList.add('指示');

    return ListTile(
      dense: true,
      leading: const Icon(Icons.settings_input_component, size: 20),
      title: Text(
        _getCharacteristicName(characteristic.uuid.toString()) ?? characteristic.uuid.toString().substring(0, 8),
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        propList.join(' | '),
        style: const TextStyle(fontSize: 11, color: Colors.blue),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (props.read)
            IconButton(
              icon: const Icon(Icons.download, size: 18),
              onPressed: () => _readCharacteristic(characteristic),
              tooltip: '读取',
            ),
          if (props.write || props.writeWithoutResponse)
            IconButton(
              icon: const Icon(Icons.upload, size: 18),
              onPressed: () => _writeCharacteristic(characteristic),
              tooltip: '写入',
            ),
          if (props.notify || props.indicate)
            IconButton(
              icon: const Icon(Icons.notifications, size: 18),
              onPressed: () => _toggleNotify(characteristic),
              tooltip: '订阅通知',
            ),
        ],
      ),
    );
  }

  Future<void> _readCharacteristic(BluetoothCharacteristic characteristic) async {
    final data = await _bleService.readData(characteristic);
    if (data != null) {
      _showDataDialog('读取结果', data);
    } else {
      _showMessage('读取失败');
    }
  }

  Future<void> _writeCharacteristic(BluetoothCharacteristic characteristic) async {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('写入数据'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '输入文本或十六进制数据',
                hintText: '例如: Hello 或 48454C4C4F',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final text = controller.text;

              // 尝试解析为十六进制
              List<int> data;
              if (RegExp(r'^[0-9A-Fa-f]+$').hasMatch(text) && text.length % 2 == 0) {
                data = [];
                for (int i = 0; i < text.length; i += 2) {
                  data.add(int.parse(text.substring(i, i + 2), radix: 16));
                }
              } else {
                data = text.codeUnits;
              }

              final success = await _bleService.writeData(
                data,
                characteristic: characteristic,
                withResponse: characteristic.properties.write,
              );
              _showMessage(success ? '写入成功' : '写入失败');
            },
            child: const Text('发送'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleNotify(BluetoothCharacteristic characteristic) async {
    final isNotifying = characteristic.isNotifying;

    bool success;
    if (isNotifying) {
      success = await _bleService.disableNotifications(characteristic);
      _showMessage(success ? '已取消订阅' : '取消订阅失败');
    } else {
      success = await _bleService.enableNotifications(characteristic);
      if (success) {
        _showMessage('已订阅通知');
        // 显示接收数据的对话框
        _showNotificationDialog(characteristic);
      } else {
        _showMessage('订阅失败');
      }
    }
  }

  void _showDataDialog(String title, List<int> data) {
    final hexString = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase();
    final textString = String.fromCharCodes(data.where((b) => b >= 32 && b < 127));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('十六进制:', style: TextStyle(fontWeight: FontWeight.bold)),
            SelectableText(hexString),
            const SizedBox(height: 8),
            const Text('文本:', style: TextStyle(fontWeight: FontWeight.bold)),
            SelectableText(textString.isEmpty ? '(无可显示文本)' : textString),
            const SizedBox(height: 8),
            Text('长度: ${data.length} 字节'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showNotificationDialog(BluetoothCharacteristic characteristic) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('接收通知数据'),
        content: SizedBox(
          width: double.maxFinite,
          height: 200,
          child: StreamBuilder<List<int>>(
            stream: _bleService.receivedData,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: Text('等待数据...'));
              }

              final data = snapshot.data!;
              final hexString = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase();
              final textString = String.fromCharCodes(data.where((b) => b >= 32 && b < 127));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('最新数据:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('HEX: $hexString'),
                  Text('TXT: ${textString.isEmpty ? "(无)" : textString}'),
                  Text('长度: ${data.length} 字节'),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _bleService.disableNotifications(characteristic);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('停止并关闭'),
          ),
        ],
      ),
    );
  }

  String? _getServiceName(String uuid) {
    final knownServices = {
      '00001800-0000-1000-8000-00805f9b34fb': 'Generic Access',
      '00001801-0000-1000-8000-00805f9b34fb': 'Generic Attribute',
      '0000180a-0000-1000-8000-00805f9b34fb': 'Device Information',
      '0000180f-0000-1000-8000-00805f9b34fb': 'Battery Service',
      '0000180d-0000-1000-8000-00805f9b34fb': 'Heart Rate',
      '00001809-0000-1000-8000-00805f9b34fb': 'Health Thermometer',
      '0000ffe0-0000-1000-8000-00805f9b34fb': 'Serial Port (HM-10)',
      '6e400001-b5a3-f393-e0a9-e50e24dcca9e': 'Nordic UART',
    };
    return knownServices[uuid.toLowerCase()];
  }

  String? _getCharacteristicName(String uuid) {
    final knownCharacteristics = {
      '00002a00-0000-1000-8000-00805f9b34fb': 'Device Name',
      '00002a01-0000-1000-8000-00805f9b34fb': 'Appearance',
      '00002a19-0000-1000-8000-00805f9b34fb': 'Battery Level',
      '00002a29-0000-1000-8000-00805f9b34fb': 'Manufacturer',
      '00002a24-0000-1000-8000-00805f9b34fb': 'Model Number',
      '0000ffe1-0000-1000-8000-00805f9b34fb': 'Serial Data',
      '6e400002-b5a3-f393-e0a9-e50e24dcca9e': 'RX Characteristic',
      '6e400003-b5a3-f393-e0a9-e50e24dcca9e': 'TX Characteristic',
    };
    return knownCharacteristics[uuid.toLowerCase()];
  }
}
