import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as classic;
import 'package:permission_handler/permission_handler.dart';

/// 能力诊断页 - 用于快速确认当前设备的蓝牙与权限支持情况
class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  final List<_DiagEntry> _entries = [];
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _entries.clear();
      _isRunning = true;
    });

    await _checkBleSupport();
    await _checkClassicSupport();
    await _checkPermissions();
    await _checkAdapterStates();

    setState(() {
      _isRunning = false;
    });
  }

  Future<void> _checkBleSupport() async {
    final supported = await FlutterBluePlus.isSupported;
    _addEntry(
      title: 'BLE 支持',
      value: supported ? '支持' : '不支持',
      level: supported ? _DiagLevel.ok : _DiagLevel.error,
    );
  }

  Future<void> _checkClassicSupport() async {
    bool available = false;
    try {
      available = await classic.FlutterBluetoothSerial.instance.isAvailable ?? false;
    } catch (_) {}

    _addEntry(
      title: '经典蓝牙支持',
      value: available ? '支持' : '不支持或权限不足',
      level: available ? _DiagLevel.ok : _DiagLevel.warn,
    );
  }

  Future<void> _checkPermissions() async {
    if (!Platform.isAndroid) {
      _addEntry(
        title: 'Android 权限',
        value: '非 Android 平台',
        level: _DiagLevel.info,
      );
      return;
    }

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    bool check(Permission permission) =>
        statuses[permission]?.isGranted == true || statuses[permission]?.isLimited == true;

    _addEntry(
      title: 'BLUETOOTH_SCAN',
      value: check(Permission.bluetoothScan) ? '已授予' : '未授予',
      level: check(Permission.bluetoothScan) ? _DiagLevel.ok : _DiagLevel.error,
    );
    _addEntry(
      title: 'BLUETOOTH_CONNECT',
      value: check(Permission.bluetoothConnect) ? '已授予' : '未授予',
      level: check(Permission.bluetoothConnect) ? _DiagLevel.ok : _DiagLevel.error,
    );
  }

  Future<void> _checkAdapterStates() async {
    try {
      final bleState = await FlutterBluePlus.adapterState.first;
      _addEntry(
        title: 'BLE 适配器',
        value: bleState == BluetoothAdapterState.on ? '已开启' : bleState.toString(),
        level: bleState == BluetoothAdapterState.on ? _DiagLevel.ok : _DiagLevel.warn,
      );
    } catch (_) {
      _addEntry(
        title: 'BLE 适配器',
        value: '状态获取失败',
        level: _DiagLevel.error,
      );
    }

    try {
      final classicState = await classic.FlutterBluetoothSerial.instance.state;
      final classicOn = classicState == classic.BluetoothState.STATE_ON;
      _addEntry(
        title: '经典蓝牙适配器',
        value: classicOn ? '已开启' : classicState.toString(),
        level: classicOn ? _DiagLevel.ok : _DiagLevel.warn,
      );
    } catch (_) {
      _addEntry(
        title: '经典蓝牙适配器',
        value: '状态获取失败或不支持',
        level: _DiagLevel.warn,
      );
    }
  }

  void _addEntry({required String title, required String value, required _DiagLevel level}) {
    setState(() {
      _entries.add(_DiagEntry(
        title: title,
        value: value,
        level: level,
        timestamp: DateTime.now(),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('能力诊断'),
        actions: [
          IconButton(
            onPressed: _isRunning ? null : _runDiagnostics,
            icon: _isRunning ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
            tooltip: '重新检测',
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          final entry = _entries[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              leading: Icon(
                _iconForLevel(entry.level),
                color: _colorForLevel(entry.level),
              ),
              title: Text(entry.title),
              subtitle: Text(entry.value),
              trailing: Text(
                _formatTime(entry.timestamp),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  IconData _iconForLevel(_DiagLevel level) {
    switch (level) {
      case _DiagLevel.ok:
        return Icons.check_circle;
      case _DiagLevel.warn:
        return Icons.error_outline;
      case _DiagLevel.error:
        return Icons.highlight_off;
      case _DiagLevel.info:
      default:
        return Icons.info_outline;
    }
  }

  Color _colorForLevel(_DiagLevel level) {
    switch (level) {
      case _DiagLevel.ok:
        return Colors.green;
      case _DiagLevel.warn:
        return Colors.orange;
      case _DiagLevel.error:
        return Colors.red;
      case _DiagLevel.info:
      default:
        return Colors.blueGrey;
    }
  }
}

class _DiagEntry {
  final String title;
  final String value;
  final _DiagLevel level;
  final DateTime timestamp;

  _DiagEntry({
    required this.title,
    required this.value,
    required this.level,
    required this.timestamp,
  });
}

enum _DiagLevel { ok, warn, error, info }
