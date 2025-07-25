import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:remocall_flutter/providers/notification_provider.dart';
import 'package:remocall_flutter/utils/theme.dart';
import 'package:remocall_flutter/utils/datetime_utils.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '알림 설정',
          style: AppTheme.headlineSmall,
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Connection Status
                _buildConnectionStatus(provider),
                const SizedBox(height: 24),
                
                // Recent Notifications
                Text(
                  '최근 알림',
                  style: AppTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                
                if (provider.isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  )
                else if (provider.notifications.isEmpty)
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '알림이 없습니다',
                          style: AppTheme.bodyLarge.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...provider.notifications.take(10).map((notification) =>
                      _buildNotificationCard(context, notification)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectionStatus(NotificationProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: provider.isConnected
            ? AppTheme.successColor.withOpacity(0.1)
            : AppTheme.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: provider.isConnected
              ? AppTheme.successColor
              : AppTheme.errorColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            provider.isConnected
                ? Icons.check_circle
                : Icons.error_outline,
            color: provider.isConnected
                ? AppTheme.successColor
                : AppTheme.errorColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.isConnected ? '연결됨' : '연결 끊김',
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  provider.isConnected
                      ? '실시간 알림을 받을 수 있습니다'
                      : '네트워크 연결을 확인해주세요',
                  style: AppTheme.bodySmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, notification) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: notification.isSent
              ? AppTheme.successColor.withOpacity(0.1)
              : AppTheme.warningColor.withOpacity(0.1),
          child: Icon(
            notification.isSent
                ? Icons.check
                : Icons.pending,
            color: notification.isSent
                ? AppTheme.successColor
                : AppTheme.warningColor,
          ),
        ),
        title: Text(
          notification.sender,
          style: AppTheme.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.message,
              style: AppTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              DateTimeUtils.getKSTShortDateTimeString(notification.receivedAt),
              style: AppTheme.bodySmall.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () {
            Provider.of<NotificationProvider>(context, listen: false)
                .deleteNotification(notification.id!);
          },
        ),
      ),
    );
  }
}