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

    _addLog(
      '系统',
      '已连接到 ${widget.device.name ?? widget.device.address}',
      isSystem: true,
    );
  }

  /// 添加日志
  void _addLog(String direction, dynamic data, {bool isSystem = false}) {
    setState(() {
      _logs.add(
        _LogEntry(
          direction: direction,
          data: data is Uint8List
              ? data
              : Uint8List.fromList(utf8.encode(data.toString())),
          timestamp: DateTime.now(),
          isSystem: isSystem,
        ),
      );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无效的十六进制格式')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('发送失败')));
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
            Text(
              widget.device.name ?? '未知设备',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              widget.device.address,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
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
          Expanded(child: _buildLogArea()),

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
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _buildQuickButton('AT', () => _quickSend('AT')),
            _buildQuickButton('OK', () => _quickSend('OK')),
            _buildQuickButton('AT+VERSION', () => _quickSend('AT+VERSION')),
            _buildQuickButton('AT+NAME', () => _quickSend('AT+NAME')),
            const VerticalDivider(width: 24),
            _buildQuickButton(
              'Hex: 00',
              () => _quickSendHex([0x00]),
              isHex: true,
            ),
            _buildQuickButton(
              'Hex: FF',
              () => _quickSendHex([0xFF]),
              isHex: true,
            ),
            _buildQuickButton('Hello', () => _quickSend('Hello')),
            _buildQuickButton(
              '\\r\\n',
              () => _quickSendHex([0x0D, 0x0A]),
              isHex: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickButton(
    String label,
    VoidCallback onPressed, {
    bool isHex = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isHex ? Colors.purple[700] : Colors.black87,
          ),
        ),
        backgroundColor: isHex ? Colors.purple[50] : Colors.grey[100],
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        onPressed: _connectionState == BluetoothConnectionState.connected
            ? onPressed
            : null,
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

    if (isSystem) {
      final systemText = _formatText(log.data);
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            systemText,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Align(
      alignment: isReceived ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isReceived ? Colors.white : Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(12).copyWith(
            topLeft: isReceived ? Radius.zero : const Radius.circular(12),
            topRight: !isReceived ? Radius.zero : const Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatText(log.data),
              style: TextStyle(
                color: isReceived ? Colors.black87 : Colors.white,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'HEX: ${_formatHex(log.data)}',
              style: TextStyle(
                color: isReceived
                    ? Colors.grey[500]
                    : Colors.white.withValues(alpha: 0.7),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                '${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: isReceived
                      ? Colors.grey[400]
                      : Colors.white.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatHex(Uint8List data) {
    return data
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  String _formatText(Uint8List data) {
    try {
      return utf8
          .decode(data, allowMalformed: true)
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _inputController,
                  decoration: InputDecoration(
                    hintText: _hexMode ? ' HEX...' : ' Message...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _sendData(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed:
                    _connectionState == BluetoothConnectionState.connected
                    ? _sendData
                    : null,
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                tooltip: 'Send',
              ),
            ),
          ],
        ),
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
