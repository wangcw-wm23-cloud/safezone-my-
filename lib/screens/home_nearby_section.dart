part of 'home_screen.dart';

extension _HomeNearbySection on _HomeScreenState {


  Widget _buildNearbyAlertsPreview() {
    if (_nearbyAlerts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        decoration: _cardDecoration(),
        child: const Column(
          children: [
            Icon(Icons.shield_outlined, color: Colors.green, size: 34),

            SizedBox(height: 9),

            Text(
              'No nearby alerts',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),

            SizedBox(height: 3),

            Text(
              'No active SafeZone emergency incidents are currently available nearby.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 8.5),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final alert in _nearbyAlerts.take(4))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildAlertListItem(alert),
          ),

        if (_nearbyAlerts.length > 4)
          TextButton(
            onPressed: _showNearbyAlerts,
            child: const Text('View All Alerts'),
          ),
      ],
    );
  }



  Widget _buildAlertListItem(_NearbyAlert alert) {
    final color = _alertColor(alert.category);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showAlertDetails(alert),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: color.withValues(alpha: 0.10),
                ),
                child: Icon(_alertIcon(alert.category), color: color, size: 20),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      '${alert.distanceKm.toStringAsFixed(1)} km away • ${alert.timeAgo}',
                      style: const TextStyle(fontSize: 8.5),
                    ),
                  ],
                ),
              ),

              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }



  Future<void> _showNearbyAlerts() async {
    await _loadNearbyAlerts();

    if (!mounted) return;

    final scheme = Theme.of(context).colorScheme;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Nearby Alerts',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    if (_nearbyAlerts.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_nearbyAlerts.length} Active',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 5),

                const Text(
                  'SafeZone incidents detected near your current location.',
                  style: TextStyle(fontSize: 9),
                ),

                const SizedBox(height: 16),

                if (_nearbyAlerts.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 20,
                    ),
                    decoration: _cardDecoration(),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: Colors.green,
                          size: 42,
                        ),

                        SizedBox(height: 10),

                        Text(
                          'All Clear',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),

                        SizedBox(height: 4),

                        Text(
                          'There are currently no active nearby SafeZone alerts.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,

                      itemCount: _nearbyAlerts.length,

                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),

                      itemBuilder: (context, index) {
                        return _buildAlertListItem(_nearbyAlerts[index]);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }



  Future<void> _showAlertDetails(_NearbyAlert alert) async {
    final color = _alertColor(alert.category);

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    _alertIcon(alert.category),
                    color: color,
                    size: 25,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  alert.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  '${alert.distanceKm.toStringAsFixed(1)} km away • ${alert.timeAgo}',
                ),

                if (alert.locationName != null) ...[
                  const SizedBox(height: 5),

                  Text(
                    alert.locationName!,
                    style: const TextStyle(fontSize: 10),
                  ),
                ],

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);

                      await Navigator.push(
                        this.context,
                        MaterialPageRoute(
                          builder: (_) =>
                              NearbySosDetailScreen(incident: alert.incident),
                        ),
                      );

                      if (!mounted) return;

                      await _loadNearbyAlerts();
                    },
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Show on Map'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
