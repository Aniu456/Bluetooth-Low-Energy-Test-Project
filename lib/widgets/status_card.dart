import 'package:flutter/material.dart';

class StatusCard extends StatelessWidget {
  final String title;
  final Widget? titleWidget;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final bool useGradient;

  const StatusCard({
    super.key,
    this.title = '',
    this.titleWidget,
    required this.children,
    this.padding = const EdgeInsets.all(20),
    this.useGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 16,
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: useGradient
              ? BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      Colors.white,
                    ],
                  ),
                )
              : null,
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (titleWidget != null) ...[
                  titleWidget!,
                  const SizedBox(height: 16),
                  Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1)),
                  const SizedBox(height: 16),
                ] else if (title.isNotEmpty) ...[
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1)),
                  const SizedBox(height: 16),
                ],
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final IconData? icon;

  const StatusRow({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: Colors.grey[600]),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: themeColor.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: themeColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
