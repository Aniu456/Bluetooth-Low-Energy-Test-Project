import 'package:flutter/material.dart';

import 'screens/scan_screen.dart';
import 'screens/classic_scan_screen.dart';
import 'screens/diagnostic_screen.dart';

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
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4), // Deep Purple
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(
          0xFFF3F4F6,
        ), // Light Grey Background
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          color: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent, // Modern transparent app bar
        ),
        navigationBarTheme: NavigationBarThemeData(
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          height: 65,
          indicatorColor: const Color(0xFFEADDFF),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Color(0xFF21005D));
            }
            return IconThemeData(color: Colors.grey[600]);
          }),
        ),
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

  final List<Widget> _screens = const [ScanScreen(), ClassicScanScreen(), DiagnosticScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
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
          NavigationDestination(
            icon: Icon(Icons.rule_folder_outlined),
            selectedIcon: Icon(Icons.rule_folder),
            label: '能力诊断',
          ),
        ],
      ),
    );
  }
}
