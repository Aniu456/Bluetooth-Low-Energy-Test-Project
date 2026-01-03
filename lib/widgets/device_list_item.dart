import 'package:flutter/material.dart';

class DeviceListItem extends StatelessWidget {
  final String name;
  final String id;
  final Widget? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;
  final int? rssi;

  const DeviceListItem({
    super.key,
    required this.name,
    required this.id,
    this.subtitle,
    this.trailing,
    this.leading,
    this.onTap,
    this.rssi,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            offset: const Offset(0, 2),
            blurRadius: 10,
          ),
        ],
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                leading ?? _buildSignalIndicator(context),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isNotEmpty ? name : '未知设备',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        id,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        DefaultTextStyle(
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          child: subtitle!,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignalIndicator(BuildContext context) {
    if (rssi != null) {
      Color signalColor;
      int bars;

      if (rssi! > -60) {
        signalColor = Colors.green;
        bars = 4;
      } else if (rssi! > -70) {
        signalColor = Colors.lightGreen;
        bars = 3;
      } else if (rssi! > -80) {
        signalColor = Colors.orange;
        bars = 2;
      } else {
        signalColor = Colors.red;
        bars = 1;
      }

      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: signalColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  width: 3,
                  height: 4.0 + (index * 3),
                  decoration: BoxDecoration(
                    color: index < bars ? signalColor : Colors.grey[300],
                    borderRadius: BorderRadius.circular(1),
                  ),
                );
              }),
            ),
            const SizedBox(height: 2),
            Text(
              '$rssi',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: signalColor,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.bluetooth,
        color: Theme.of(context).primaryColor,
        size: 20,
      ),
    );
  }
}
