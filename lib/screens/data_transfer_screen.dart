import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/ble_service.dart';

/// 数据传输测试页面 - 专门用于测试数据收发
class DataTransferScreen extends StatefulWidget {
  const DataTransferScreen({super.key});

  @override
  State<DataTransferScreen> createState() => _DataTransferScreenState();
}

class _DataTransferScreenState extends State<DataTransferScreen> {
  final BleService _bleService = BleService();
  final TextEditingController _sendController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 收发日志
  final List<_TransferLog> _logs = [];

  // 选择的特征
  BluetoothCharacteristic? _selectedWriteChar;
  BluetoothCharacteristic? _selectedNotifyChar;

  // 发送模式
  bool _sendAsHex = false;
  bool _autoScroll = true;
  bool _isNotifying = false;

  StreamSubscription? _dataSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _initializeCharacteristics();
    _subscribeToData();
    _subscribeConnectionState();
  }

  void _initializeCharacteristics() {
    final writeChars = _collectWriteCharacteristics();
    final notifyChars = _collectNotifyCharacteristics();

    setState(() {
      _selectedWriteChar = writeChars.isNotEmpty ? writeChars.first : null;
      _selectedNotifyChar = notifyChars.isNotEmpty ? notifyChars.first : null;
    });
  }

  List<BluetoothCharacteristic> _collectWriteCharacteristics() {
    final writeChars = <BluetoothCharacteristic>[];
    for (var service in _bleService.services) {
      for (var char in service.characteristics) {
        if (char.properties.write || char.properties.writeWithoutResponse) {
          writeChars.add(char);
        }
      }
    }
    return writeChars;
  }

  List<BluetoothCharacteristic> _collectNotifyCharacteristics() {
    final notifyChars = <BluetoothCharacteristic>[];
    for (var service in _bleService.services) {
      for (var char in service.characteristics) {
        if (char.properties.notify || char.properties.indicate) {
          notifyChars.add(char);
        }
      }
    }
    return notifyChars;
  }

  void _ensureValidSelections(
    List<BluetoothCharacteristic> writeChars,
    List<BluetoothCharacteristic> notifyChars,
  ) {
    final newWrite = _isCharacteristicAvailable(_selectedWriteChar, writeChars)
        ? _selectedWriteChar
        : (writeChars.isNotEmpty ? writeChars.first : null);
    final newNotify = _isCharacteristicAvailable(_selectedNotifyChar, notifyChars)
        ? _selectedNotifyChar
        : (notifyChars.isNotEmpty ? notifyChars.first : null);

    if (newWrite != _selectedWriteChar || newNotify != _selectedNotifyChar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedWriteChar = newWrite;
          _selectedNotifyChar = newNotify;
          if (newNotify == null) {
            _isNotifying = false;
          }
        });
      });
    }
  }

  bool _isCharacteristicAvailable(
    BluetoothCharacteristic? characteristic,
    List<BluetoothCharacteristic> list,
  ) {
    if (characteristic == null) return false;
    return list.contains(characteristic);
  }

  void _subscribeToData() {
    _dataSubscription = _bleService.receivedData.listen((data) {
      _addLog(_TransferLog(
        type: LogType.receive,
        data: data,
        timestamp: DateTime.now(),
      ));
    });
  }

  void _subscribeConnectionState() {
    _connectionSubscription = _bleService.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        if (mounted) {
          setState(() {
            _isNotifying = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _sendController.dispose();
    _scrollController.dispose();
    _dataSubscription?.cancel();
    _connectionSubscription?.cancel();
    if (_isNotifying && _selectedNotifyChar != null) {
      _bleService.disableNotifications(_selectedNotifyChar);
    }
    super.dispose();
  }

  void _addLog(_TransferLog log) {
    setState(() {
      _logs.add(log);
    });

    if (_autoScroll) {
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
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  Future<void> _sendData() async {
    final writeChars = _collectWriteCharacteristics();
    if (!_isCharacteristicAvailable(_selectedWriteChar, writeChars)) {
      _showMessage('请先选择写入特征');
      return;
    }

    final writeChar = _selectedWriteChar!;
    final text = _sendController.text;
    if (text.isEmpty) return;

    List<int> data;
    if (_sendAsHex) {
      // 解析十六进制
      final hexString = text.replaceAll(' ', '');
      if (!RegExp(r'^[0-9A-Fa-f]+$').hasMatch(hexString) || hexString.length % 2 != 0) {
        _showMessage('无效的十六进制格式');
        return;
      }
      data = [];
      for (int i = 0; i < hexString.length; i += 2) {
        data.add(int.parse(hexString.substring(i, i + 2), radix: 16));
      }
    } else {
      data = text.codeUnits;
    }

    final success = await _bleService.writeData(
      data,
      characteristic: writeChar,
      withResponse: writeChar.properties.write,
    );

    if (success) {
      _addLog(_TransferLog(
        type: LogType.send,
        data: data,
        timestamp: DateTime.now(),
      ));
      _sendController.clear();
    } else {
      _showMessage('发送失败');
    }
  }

  Future<void> _toggleNotify() async {
    final notifyChars = _collectNotifyCharacteristics();
    if (!_isCharacteristicAvailable(_selectedNotifyChar, notifyChars)) {
      _showMessage('请先选择通知特征');
      return;
    }

    final notifyChar = _selectedNotifyChar!;
    if (_isNotifying) {
      final success = await _bleService.disableNotifications(notifyChar);
      if (success) {
        setState(() {
          _isNotifying = false;
        });
        _showMessage('已停止接收');
      }
    } else {
      final success = await _bleService.enableNotifications(notifyChar);
      if (success) {
        setState(() {
          _isNotifying = true;
        });
        _showMessage('开始接收数据');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据传输测试'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _clearLogs,
            icon: const Icon(Icons.delete_sweep),
            tooltip: '清空日志',
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _autoScroll = !_autoScroll;
              });
            },
            icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.expand),
            tooltip: _autoScroll ? '自动滚动: 开' : '自动滚动: 关',
          ),
        ],
      ),
      body: Column(
        children: [
          // 特征选择
          _buildCharacteristicSelector(),

          // 日志区域
          Expanded(
            child: _buildLogArea(),
          ),

          // 发送区域
          _buildSendArea(),
        ],
      ),
    );
  }

  Widget _buildCharacteristicSelector() {
    final writeChars = _collectWriteCharacteristics();
    final notifyChars = _collectNotifyCharacteristics();
    _ensureValidSelections(writeChars, notifyChars);
    final selectedWriteChar = _isCharacteristicAvailable(_selectedWriteChar, writeChars) ? _selectedWriteChar : null;
    final selectedNotifyChar = _isCharacteristicAvailable(_selectedNotifyChar, notifyChars) ? _selectedNotifyChar : null;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('特征选择', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            // 写入特征选择
            Row(
              children: [
                const Text('写入: ', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: DropdownButton<BluetoothCharacteristic>(
                    value: selectedWriteChar,
                    isExpanded: true,
                    hint: const Text('选择写入特征'),
                    items: writeChars.map((char) {
                      return DropdownMenuItem(
                        value: char,
                        child: Text(
                          char.uuid.toString().substring(0, 8),
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                    onChanged: (char) {
                      setState(() {
                        _selectedWriteChar = char;
                      });
                    },
                  ),
                ),
              ],
            ),

            // 通知特征选择
            Row(
              children: [
                const Text('通知: ', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: DropdownButton<BluetoothCharacteristic>(
                    value: selectedNotifyChar,
                    isExpanded: true,
                    hint: const Text('选择通知特征'),
                    items: notifyChars.map((char) {
                      return DropdownMenuItem(
                        value: char,
                        child: Text(
                          char.uuid.toString().substring(0, 8),
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                    onChanged: (char) async {
                      if (char == null) return;

                      if (_isNotifying && char != _selectedNotifyChar) {
                        final previousChar = _selectedNotifyChar;
                        final disabled = previousChar == null || await _bleService.disableNotifications(previousChar);

                        if (!disabled) {
                          _showMessage('切换通知特征失败');
                          return;
                        }

                        final enabled = await _bleService.enableNotifications(char);

                        if (!mounted) return;
                        setState(() {
                          _selectedNotifyChar = char;
                          _isNotifying = enabled;
                        });

                        if (!enabled) {
                          _showMessage('切换通知特征失败');
                        }
                      } else {
                        setState(() {
                          _selectedNotifyChar = char;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _toggleNotify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isNotifying ? Colors.red[100] : Colors.green[100],
                  ),
                  child: Text(_isNotifying ? '停止' : '监听'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogArea() {
    if (_logs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无数据', style: TextStyle(color: Colors.grey)),
            Text('发送数据或开启通知监听', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          return _buildLogItem(_logs[index]);
        },
      ),
    );
  }

  Widget _buildLogItem(_TransferLog log) {
    final isSend = log.type == LogType.send;
    final hexString = log.data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase();
    final textString = String.fromCharCodes(log.data.where((b) => b >= 32 && b < 127));
    final time = '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSend ? Colors.blue[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSend ? Colors.blue[200]! : Colors.green[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSend ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: isSend ? Colors.blue : Colors.green,
              ),
              const SizedBox(width: 4),
              Text(
                isSend ? '发送' : '接收',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSend ? Colors.blue : Colors.green,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                time,
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
              const SizedBox(width: 8),
              Text(
                '${log.data.length} 字节',
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'HEX: $hexString',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
          if (textString.isNotEmpty)
            Text(
              'TXT: $textString',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _buildSendArea() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey[300]!,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 模式切换
            Row(
              children: [
                const Text('发送模式: '),
                ChoiceChip(
                  label: const Text('文本'),
                  selected: !_sendAsHex,
                  onSelected: (selected) {
                    setState(() {
                      _sendAsHex = false;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('十六进制'),
                  selected: _sendAsHex,
                  onSelected: (selected) {
                    setState(() {
                      _sendAsHex = true;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 快捷发送按钮
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickSendButton('AT', [0x41, 0x54]),
                  _buildQuickSendButton('OK', [0x4F, 0x4B]),
                  _buildQuickSendButton('0x00', [0x00]),
                  _buildQuickSendButton('0xFF', [0xFF]),
                  _buildQuickSendButton('Hello', 'Hello'.codeUnits),
                  _buildQuickSendButton('回车换行', [0x0D, 0x0A]),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 输入框和发送按钮
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sendController,
                    decoration: InputDecoration(
                      hintText: _sendAsHex ? '输入十六进制 (如: 48 45 4C 4C 4F)' : '输入文本',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _sendData(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _sendData,
                  icon: const Icon(Icons.send),
                  label: const Text('发送'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSendButton(String label, List<int> data) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton(
        onPressed: () async {
          final writeChars = _collectWriteCharacteristics();
          if (!_isCharacteristicAvailable(_selectedWriteChar, writeChars)) {
            _showMessage('请先选择写入特征');
            return;
          }

          final writeChar = _selectedWriteChar!;
          final success = await _bleService.writeData(
            data,
            characteristic: writeChar,
            withResponse: writeChar.properties.write,
          );

          if (success) {
            _addLog(_TransferLog(
              type: LogType.send,
              data: data,
              timestamp: DateTime.now(),
            ));
          } else {
            _showMessage('发送失败');
          }
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 32),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

// 日志类型
enum LogType { send, receive }

// 传输日志
class _TransferLog {
  final LogType type;
  final List<int> data;
  final DateTime timestamp;

  _TransferLog({
    required this.type,
    required this.data,
    required this.timestamp,
  });
}
