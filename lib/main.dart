import 'package:flutter/material.dart';

import 'screens/scan_screen.dart';
import 'screens/classic_scan_screen.dart';

void main() {
  runApp(const BleTestApp());
}

/// 蓝牙测试应用
///
/// 功能:
/// 1. BLE 低功耗蓝牙 - 扫描、连接、服务发现、数据传输
/// 2. 经典蓝牙 - 扫描、配对、SPP 串口通信
class BleTestApp extends StatelessWidget {
  const BleTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '蓝牙测试工具',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

/// 主页 - 蓝牙类型选择
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ScanScreen(),
    ClassicScanScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bluetooth_searching),
            selectedIcon: Icon(Icons.bluetooth_connected),
            label: 'BLE 低功耗',
          ),
          NavigationDestination(
            icon: Icon(Icons.bluetooth),
            selectedIcon: Icon(Icons.bluetooth_audio),
            label: '经典蓝牙',
          ),
        ],
      ),
    );
  }
}
