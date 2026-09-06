part of 'home_screen.dart';

extension _HomeSafetySection on _HomeScreenState {

  Widget _buildSafetySheet() {
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.30,

      minChildSize: 0.20,

      maxChildSize: 0.78,

      snap: true,

      snapSizes: const [0.20, 0.30, 0.78],

      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: [


              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              _buildSheetLocationHeader(),

              const SizedBox(height: 15),

              _buildCompactRiskCard(),


              if (!_setupLoading && !_setupComplete) ...[
                const SizedBox(height: 12),

                _buildSetupStatusCard(),
              ],

              const SizedBox(height: 12),

              _buildNearbyAlertButton(),

              const SizedBox(height: 20),

              _sheetSectionTitle('Safety Details'),

              const SizedBox(height: 10),

              _buildDetailedRiskStats(),

              const SizedBox(height: 14),

              _buildRiskDescriptionCard(),

              const SizedBox(height: 22),

              _sheetSectionTitle('Nearby Alerts'),

              const SizedBox(height: 10),

              _HomeNearbySection(this)._buildNearbyAlertsPreview(),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }


  Widget _buildSheetLocationHeader() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withValues(alpha: 0.12),
          ),
          child: _locationLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(
                  Icons.my_location_rounded,
                  color: Colors.blue,
                  size: 21,
                ),
        ),

        const SizedBox(width: 11),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _locationName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                _district,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9.5),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        IconButton(
          tooltip: 'Locate me',
          onPressed: _onLocationAction,
          icon: const Icon(Icons.gps_fixed_rounded),
        ),
      ],
    );
  }


  Widget _buildCompactRiskCard() {
    final riskColor = _riskColor();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Risk', style: TextStyle(fontSize: 9)),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: riskColor,
                          ),
                        ),

                        const SizedBox(width: 7),

                        Text(
                          _riskLevel,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: riskColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Risk Score', style: TextStyle(fontSize: 9)),

                  const SizedBox(height: 3),

                  Text(
                    _riskAvailable ? '$_riskScore / 100' : '-- / 100',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 11),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: _riskAvailable ? _riskScore / 100 : 0,
              minHeight: 6,
              color: riskColor,
              backgroundColor: riskColor.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSetupStatusCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: Colors.orange,
                size: 19,
              ),

              SizedBox(width: 8),

              Expanded(
                child: Text(
                  'Safety Setup Incomplete',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          const Text(
            'Complete the required items before using SOS.',
            style: TextStyle(fontSize: 9),
          ),

          const SizedBox(height: 12),

          _setupStatusRow(
            icon: Icons.phone_android_rounded,

            title: 'Phone Verification',

            subtitle: _phoneVerified
                ? 'Verified'
                : !_hasPhoneNumber
                ? 'Phone number required'
                : 'Verification required',

            complete: _phoneVerified,

            onFix: _phoneVerified ? null : _openPersonalInformation,
          ),

          const SizedBox(height: 9),

          _setupStatusRow(
            icon: Icons.devices_rounded,

            title: 'Device Binding',

            subtitle: _hasBoundDevice ? 'Completed' : 'Device binding required',

            complete: _hasBoundDevice,

            onFix: _hasBoundDevice ? null : _openRegisteredDevice,
          ),
        ],
      ),
    );
  }


  Widget _setupStatusRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool complete,
    required VoidCallback? onFix,
  }) {
    final color = complete ? Colors.green : Colors.orange;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: color.withValues(alpha: 0.10),
          ),
          child: Icon(
            complete ? Icons.check_rounded : icon,
            color: color,
            size: 18,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),

              Text(subtitle, style: TextStyle(fontSize: 8.5, color: color)),
            ],
          ),
        ),

        if (!complete && onFix != null)
          TextButton(onPressed: onFix, child: const Text('Fix')),
      ],
    );
  }


  Widget _buildNearbyAlertButton() {
    final hasAlerts = _nearbyAlerts.isNotEmpty;

    final color = hasAlerts ? Colors.orange : Colors.green;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _HomeNearbySection(this)._showNearbyAlerts,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: color.withValues(alpha: 0.07),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 37,
                height: 37,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                ),
                child: Icon(
                  hasAlerts
                      ? Icons.crisis_alert_rounded
                      : Icons.check_circle_outline_rounded,
                  color: color,
                  size: 20,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasAlerts ? 'Nearby Alerts' : 'All Clear Nearby',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      hasAlerts
                          ? '${_nearbyAlerts.length} active alert${_nearbyAlerts.length == 1 ? '' : 's'} within your nearby area'
                          : 'No active SafeZone incidents nearby',
                      style: const TextStyle(fontSize: 8.5),
                    ),
                  ],
                ),
              ),

              if (hasAlerts)
                Container(
                  constraints: const BoxConstraints(minWidth: 27),
                  height: 27,
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_nearbyAlerts.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              const SizedBox(width: 5),

              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedRiskStats() {
    return Row(
      children: [
        Expanded(
          child: _detailStat(
            icon: Icons.bar_chart_rounded,
            title: 'Historical Cases',
            value: _riskAvailable ? _formatNumber(_historicalCases) : '--',
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _detailStat(
            icon: Icons.warning_amber_rounded,
            title: 'Active Incidents',
            value: '${_nearbyAlerts.length}',
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _detailStat(
            icon: Icons.speed_rounded,
            title: 'Crime Rate',
            value: _crimeRatePer100k != null
                ? _crimeRatePer100k!.toStringAsFixed(1)
                : '--',
          ),
        ),
      ],
    );
  }

  Widget _detailStat({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Icon(icon, size: 18),

          const SizedBox(height: 6),

          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 2),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 7.5),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskDescriptionCard() {
    final color = _riskColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: color.withValues(alpha: 0.07),
        border: Border.all(color: color.withValues(alpha: 0.17)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: color, size: 18),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              _riskDescription(),
              style: const TextStyle(fontSize: 9, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }


  Widget _sheetSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
    );
  }
}
