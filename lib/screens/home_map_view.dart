part of 'home_screen.dart';

extension _HomeMapView on _HomeScreenState {
  // ============================================================
  // HOME MAP
  // ============================================================

  Widget _buildMapHome() {
    return Stack(
      children: [
        // ======================================================
        // REAL MAP
        // ======================================================

        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,

            options: MapOptions(
              initialCenter: _currentMapLocation,

              initialZoom: 16,

              onMapReady: () {
                _mapReady = true;

                _moveMapToCurrentLocation();
              },
            ),

            children: [
              // =================================================
              // OPENSTREETMAP
              // =================================================

              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

                userAgentPackageName: 'com.example.safezone_my',
              ),

              // =================================================
              // MARKERS
              // =================================================
              MarkerLayer(markers: _buildMapMarkers()),
            ],
          ),
        ),

        // ======================================================
        // DARK MAP TOP FADE
        // ======================================================
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 125,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.48),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // ======================================================
        // HEADER
        // ======================================================
        _buildFloatingHeader(),

        // ======================================================
        // MAP CONTROLS
        // ======================================================
        Positioned(
          right: 16,
          top: MediaQuery.of(context).padding.top + 88,
          child: _buildMapControls(),
        ),

        // ======================================================
        // OSM ATTRIBUTION
        // ======================================================
        Positioned(
          left: 12,
          top: MediaQuery.of(context).padding.top + 98,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '© OpenStreetMap contributors',
              style: TextStyle(color: Colors.white, fontSize: 7),
            ),
          ),
        ),

        // ======================================================
        // DRAGGABLE SAFETY PANEL
        // ======================================================
        _HomeSafetySection(this)._buildSafetySheet(),
      ],
    );
  }

  // ============================================================
  // FLOATING HEADER
  // ============================================================

  Widget _buildFloatingHeader() {
    final scheme = Theme.of(context).colorScheme;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 14,
      right: 14,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: scheme.primary.withValues(alpha: 0.15),
              ),
              child: Icon(
                Icons.shield_rounded,
                color: scheme.primary,
                size: 22,
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, $_userName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 1),

                  const Text(
                    'Stay aware. Stay safe.',
                    style: TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),

            // ==================================================
            // REFRESH
            // ==================================================
            IconButton(
              tooltip: 'Refresh location',
              onPressed: _locationLoading ? null : _refreshHome,
              icon: _locationLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),

            // ==================================================
            // NOTIFICATION
            // ==================================================
            IconButton(
              tooltip: 'Nearby alerts',
              onPressed: _HomeNearbySection(this)._showNearbyAlerts,
              icon: Badge(
                isLabelVisible: _nearbyAlerts.isNotEmpty,
                label: _nearbyAlerts.isNotEmpty
                    ? Text('${_nearbyAlerts.length}')
                    : null,
                child: const Icon(Icons.notifications_none_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MAP CONTROLS
  // ============================================================

  Widget _buildMapControls() {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ======================================================
        // RECENTER
        // ======================================================

        _mapControlButton(
          icon: Icons.my_location_rounded,
          tooltip: 'My location',
          onTap: _onLocationAction,
        ),

        const SizedBox(height: 10),

        // ======================================================
        // ALERTS
        // ======================================================
        Material(
          color: scheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: _HomeNearbySection(this)._showNearbyAlerts,
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Badge(
                isLabelVisible: _nearbyAlerts.isNotEmpty,
                label: _nearbyAlerts.isNotEmpty
                    ? Text('${_nearbyAlerts.length}')
                    : null,
                child: const Icon(Icons.crisis_alert_outlined, size: 21),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MAP CONTROL BUTTON
  // ============================================================

  Widget _mapControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, size: 21),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MAP MARKERS
  // ============================================================

  List<Marker> _buildMapMarkers() {
    final markers = <Marker>[];

    // ==========================================================
    // USER MARKER
    // ==========================================================

    if (_currentLatitude != null && _currentLongitude != null) {
      markers.add(
        Marker(
          point: LatLng(_currentLatitude!, _currentLongitude!),
          width: 54,
          height: 54,
          child: _buildUserMarker(),
        ),
      );
    }

    // ==========================================================
    // NEARBY ALERT MARKERS
    // ==========================================================

    for (final alert in _nearbyAlerts) {
      markers.add(
        Marker(
          point: LatLng(alert.latitude, alert.longitude),
          width: 48,
          height: 48,
          child: GestureDetector(
            onTap: () => _HomeNearbySection(this)._showAlertDetails(alert),
            child: _buildAlertMarker(alert),
          ),
        ),
      );
    }

    return markers;
  }

  // ============================================================
  // USER MARKER
  // ============================================================

  Widget _buildUserMarker() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue.withValues(alpha: 0.18),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 29,
        height: 29,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.5),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.navigation_rounded,
          color: Colors.white,
          size: 15,
        ),
      ),
    );
  }

  // ============================================================
  // ALERT MARKER
  // ============================================================

  Widget _buildAlertMarker(_NearbyAlert alert) {
    final color = _alertColor(alert.category);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 31,
        height: 31,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(_alertIcon(alert.category), color: Colors.white, size: 16),
      ),
    );
  }
}
