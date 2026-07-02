import 'package:flutter/material.dart';
import '../../core/extensions/datetime_extensions.dart';
import '../../data/models/device.dart';

/// A tile representing a discovered or paired device in the device list.
class DeviceListTile extends StatelessWidget {
  final Device device;
  final VoidCallback? onTap;
  final VoidCallback? onSend;

  const DeviceListTile({
    super.key,
    required this.device,
    this.onTap,
    this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: _buildAvatar(colorScheme),
        title: Text(
          device.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        subtitle: Row(
          children: [
            Flexible(
              child: Text(
                device.isOnline
                    ? '${device.ip}:${device.port}  在线'
                    : device.lastSeenAt != null
                        ? '最后在线 ${device.lastSeenAt!.relativeTime}'
                        : '离线',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (device.isPaired) ...[
              const SizedBox(width: 6),
              Icon(
                device.isVerified ? Icons.verified : Icons.lock,
                size: 14,
                color: device.isVerified ? Colors.blue : Colors.green,
              ),
            ],
          ],
        ),
        trailing: device.isOnline
            ? FilledButton.tonal(
                onPressed: onSend,
                child: const Text('发送'),
              )
            : null,
      ),
    );
  }

  Widget _buildAvatar(ColorScheme colorScheme) {
    if (device.isPaired) {
      return CircleAvatar(
        backgroundColor: device.isVerified
            ? Colors.blue.withOpacity(0.2)
            : Colors.green.withOpacity(0.2),
        child: Icon(
          Icons.phone_android,
          color: device.isVerified ? Colors.blue : Colors.green,
        ),
      );
    }

    return CircleAvatar(
      backgroundColor: colorScheme.primaryContainer,
      child: Icon(
        Icons.devices,
        color: colorScheme.onPrimaryContainer,
      ),
    );
  }
}
