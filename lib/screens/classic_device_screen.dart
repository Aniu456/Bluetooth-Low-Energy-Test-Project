import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import '../services/classic_bluetooth_service.dart';

/// 经典蓝牙设备详情和数据传输界面
class ClassicDeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const ClassicDeviceScreen({super.key, required this.device});

  @override
  State<ClassicDeviceScreen> createState() => _ClassicDeviceScreenState();
}

class _ClassicDeviceScreenState extends State<ClassicDeviceScreen> {
  final ClassicBluetoothService _btService = ClassicBluetoothService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 连接状态
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.connected;

  // 消息日志
  final List<_LogEntry> _logs = [];

  // 发送模式
  bool _hexMode = false;
  bool _appendNewline = true;

  // 订阅
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<Uint8List>? _receivedDataSubscription;

  @override
  void initState() {
    super.initState();
    _setupSubscriptions();
  }

  void _setupSubscriptions() {
    _connectionStateSubscription = _btService.connectionState.listen((state) {
      setState(() {
        _connectionState = state;
      });

      if (state == BluetoothConnectionState.disconnected) {
        _addLog('系统', '连接已断开', isSystem: true);
      }
    });

    _receivedDataSubscription = _btService.receivedData.listen((data) {
      _addLog('收到', data);
    });

    _addLog('系统', '已连接到 ${widget.device.name ?? widget.device.address}', isSystem: true);
  }

  /// 添加日志
  void _addLog(String direction, dynamic data, {bool isSystem = false}) {
    setState(() {
      _logs.add(_LogEntry(
        direction: direction,
        data: data is Uint8List ? data : Uint8List.fromList(utf8.encode(data.toString())),
        timestamp: DateTime.now(),
        isSystem: isSystem,
      ));
    });

    // 自动滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 发送数据
  Future<void> _sendData() async {
    final text = _inputController.text;
    if (text.isEmpty) return;

    Uint8List data;

    if (_hexMode) {
      // 解析十六进制
      try {
        final hexStr = text.replaceAll(' ', '').replaceAll('-', '');
        final bytes = <int>[];
        for (var i = 0; i < hexStr.length; i += 2) {
          if (i + 2 <= hexStr.length) {
            bytes.add(int.parse(hexStr.substring(i, i + 2), radix: 16));
          }
        }
        data = Uint8List.fromList(bytes);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无效的十六进制格式')),
        );
        return;
      }
    } else {
      // 文本模式
      final sendText = _appendNewline ? '$text\r\n' : text;
      data = Uint8List.fromList(utf8.encode(sendText));
    }

    final success = await _btService.sendData(data);

    if (success) {
      _addLog('发送', data);
      _inputController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('发送失败')),
      );
    }
  }

  /// 快速发送
  Future<void> _quickSend(String text) async {
    final data = Uint8List.fromList(utf8.encode('$text\r\n'));
    final success = await _btService.sendData(data);
    if (success) {
      _addLog('发送', data);
    }
  }

  /// 快速发送十六进制
  Future<void> _quickSendHex(List<int> bytes) async {
    final data = Uint8List.fromList(bytes);
    final success = await _btService.sendData(data);
    if (success) {
      _addLog('发送', data);
    }
  }

  /// 断开连接
  Future<void> _disconnect() async {
    await _btService.disconnect();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  /// 清空日志
  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _receivedDataSubscription?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.device.name ?? '未知设备', style: const TextStyle(fontSize: 16)),
            Text(
              widget.device.address,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          // 连接状态指示
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _connectionState == BluetoothConnectionState.connected
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ),
          ),
          // 清空日志
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空日志',
            onPressed: _clearLogs,
          ),
          // 断开连接
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled),
            tooltip: '断开连接',
            onPressed: _disconnect,
          ),
        ],
      ),
      body: Column(
        children: [
          // 快捷发送按钮
          _buildQuickSendBar(),

          // 日志显示区域
          Expanded(
            child: _buildLogArea(),
          ),

          // 发送选项
          _buildSendOptions(),

          // 输入区域
          _buildInputArea(),
        ],
      ),
    );
  }

  /// 构建快捷发送栏
  Widget _buildQuickSendBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.grey[100],
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildQuickButton('AT', () => _quickSend('AT')),
            _buildQuickButton('OK', () => _quickSend('OK')),
            _buildQuickButton('AT+VERSION', () => _quickSend('AT+VERSION')),
            _buildQuickButton('AT+NAME', () => _quickSend('AT+NAME')),
            _buildQuickButton('0x00', () => _quickSendHex([0x00])),
            _buildQuickButton('0xFF', () => _quickSendHex([0xFF])),
            _buildQuickButton('Hello', () => _quickSend('Hello')),
            _buildQuickButton('\\r\\n', () => _quickSendHex([0x0D, 0x0A])),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton(
        onPressed: _connectionState == BluetoothConnectionState.connected
            ? onPressed
            : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  /// 构建日志区域
  Widget _buildLogArea() {
    if (_logs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无通信记录', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        return _buildLogItem(log);
      },
    );
  }

  Widget _buildLogItem(_LogEntry log) {
    final isReceived = log.direction == '收到';
    final isSystem = log.isSystem;

    Color bgColor;
    Color textColor;
    IconData icon;

    if (isSystem) {
      bgColor = Colors.grey[200]!;
      textColor = Colors.grey[700]!;
      icon = Icons.info_outline;
    } else if (isReceived) {
      bgColor = Colors.blue[50]!;
      textColor = Colors.blue[900]!;
      icon = Icons.arrow_downward;
    } else {
      bgColor = Colors.green[50]!;
      textColor = Colors.green[900]!;
      icon = Icons.arrow_upward;
    }

    final timeStr =
        '${log.timestamp.hour.toString().padLeft(2, '0')}:'
        '${log.timestamp.minute.toString().padLeft(2, '0')}:'
        '${log.timestamp.second.toString().padLeft(2, '0')}.'
        '${log.timestamp.millisecond.toString().padLeft(3, '0')}';

    return Card(
      color: bgColor,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部
            Row(
              children: [
                Icon(icon, size: 16, color: textColor),
                const SizedBox(width: 4),
                Text(
                  log.direction,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                Text(
                  '${log.data.length} bytes',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),

            if (!isSystem) ...[
              const SizedBox(height: 8),
              // HEX 格式
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'HEX: ${_formatHex(log.data)}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // 文本格式
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'TXT: ${_formatText(log.data)}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                _formatText(log.data),
                style: TextStyle(color: textColor),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatHex(Uint8List data) {
    return data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  }

  String _formatText(Uint8List data) {
    try {
      return utf8.decode(data, allowMalformed: true)
          .replaceAll('\r', '\\r')
          .replaceAll('\n', '\\n')
          .replaceAll('\t', '\\t');
    } catch (e) {
      return '<无法解码>';
    }
  }

  /// 构建发送选项
  Widget _buildSendOptions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          // HEX 模式切换
          FilterChip(
            label: const Text('HEX'),
            selected: _hexMode,
            onSelected: (selected) {
              setState(() {
                _hexMode = selected;
              });
            },
          ),
          const SizedBox(width: 8),
          // 添加换行符
          if (!_hexMode)
            FilterChip(
              label: const Text('添加换行'),
              selected: _appendNewline,
              onSelected: (selected) {
                setState(() {
                  _appendNewline = selected;
                });
              },
            ),
          const Spacer(),
          // 提示
          Text(
            _hexMode ? '输入格式: FF 00 AB' : '文本模式',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// 构建输入区域
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              decoration: InputDecoration(
                hintText: _hexMode ? '输入十六进制数据...' : '输入文本消息...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendData(),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _connectionState == BluetoothConnectionState.connected
                ? _sendData
                : null,
            mini: true,
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

/// 日志条目
class _LogEntry {
  final String direction;
  final Uint8List data;
  final DateTime timestamp;
  final bool isSystem;

  _LogEntry({
    required this.direction,
    required this.data,
    required this.timestamp,
    this.isSystem = false,
  });
}
