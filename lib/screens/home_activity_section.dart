part of 'home_screen.dart';

extension _HomeActivitySection on _HomeScreenState {
  // ============================================================
  // ACTIVITY PAGE
  // ============================================================

  Widget _buildActivityPage() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Activity',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 4),

          const Text(
            'Your SafeZone emergency and assistance history.',
            style: TextStyle(fontSize: 10),
          ),

          const SizedBox(height: 28),

          if (_activityLoading)
            const Padding(
              padding: EdgeInsets.only(top: 70),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_activities.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 22),
              decoration: _cardDecoration(),
              child: const Column(
                children: [
                  Icon(Icons.history_rounded, size: 52),

                  SizedBox(height: 14),

                  Text(
                    'No activity yet',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),

                  SizedBox(height: 5),

                  Text(
                    'SOS requests and incidents you respond to will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10),
                  ),
                ],
              ),
            )
          else ...[
            for (final activity in _activities)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildActivityItem(activity),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final activityType = activity['activity_type']?.toString() ?? 'requested';

    final status = activity['status']?.toString() ?? 'active';

    final title = activity['title']?.toString() ?? 'SOS Emergency';

    final location = activity['location']?.toString();

    final createdAt = DateTime.tryParse(
      activity['created_at']?.toString() ?? '',
    );

    final isRequested = activityType == 'requested';

    final isActive = status == 'active' || status == 'accepted';

    final Color statusColor;

    switch (status) {
      case 'resolved':
      case 'completed':
        statusColor = Colors.green;
        break;

      case 'cancelled':
        statusColor = Colors.grey;
        break;

      case 'accepted':
        statusColor = Colors.orange;
        break;

      case 'active':
      default:
        statusColor = Colors.red;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: isRequested && isActive ? () => _openActivity(activity) : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.10),
                ),
                child: Icon(
                  isRequested
                      ? Icons.sos_rounded
                      : Icons.volunteer_activism_rounded,
                  color: statusColor,
                  size: 21,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        const SizedBox(width: 7),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 7.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      isRequested ? 'SOS Requested' : 'Joined as Helper',
                      style: const TextStyle(fontSize: 9),
                    ),

                    if (location != null && location.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),

                      Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 8.5),
                      ),
                    ],

                    if (createdAt != null) ...[
                      const SizedBox(height: 4),

                      Text(
                        _formatActivityDate(createdAt),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 8,
                        ),
                      ),
                    ],

                    if (isRequested && isActive) ...[
                      const SizedBox(height: 6),

                      const Text(
                        'Tap to return to live SOS',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (isRequested && isActive)
                const Padding(
                  padding: EdgeInsets.only(top: 13),
                  child: Icon(Icons.chevron_right_rounded, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatActivityDate(DateTime value) {
    final local = value.toLocal();

    final hour = local.hour.toString().padLeft(2, '0');

    final minute = local.minute.toString().padLeft(2, '0');

    return '${local.day}/${local.month}/${local.year}  '
        '$hour:$minute';
  }
}
