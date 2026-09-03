import 'package:flutter/material.dart';

import '../models/coordination_models.dart';
import '../services/emergency_coordination_service.dart';
import 'nearby_sos_detail_screen.dart';

class NearbySosScreen extends StatefulWidget {
  const NearbySosScreen({
    super.key,
  });

  @override
  State<NearbySosScreen> createState() =>
      _NearbySosScreenState();
}

class _NearbySosScreenState
    extends State<NearbySosScreen> {
  bool _loading = true;

  String? _error;

  List<NearbySosIncident> _incidents = const [];

  @override
  void initState() {
    super.initState();

    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final incidents =
      await EmergencyCoordinationService
          .instance
          .getNearbyIncidents();

      if (!mounted) return;

      setState(() {
        _incidents = incidents;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = _cleanError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nearby SOS',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading
                ? null
                : _load,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 240,
          ),
          Center(
            child: CircularProgressIndicator(),
          ),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(
            height: 100,
          ),
          const Icon(
            Icons.location_off_outlined,
            size: 60,
          ),
          const SizedBox(
            height: 16,
          ),
          Text(
            _error!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(
            height: 16,
          ),
          FilledButton(
            onPressed: _load,
            child: const Text(
              'Try Again',
            ),
          ),
        ],
      );
    }

    if (_incidents.isEmpty) {
      return ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(30),
        children: const [
          SizedBox(
            height: 90,
          ),
          Icon(
            Icons.health_and_safety_outlined,
            size: 72,
            color: Colors.green,
          ),
          SizedBox(
            height: 18,
          ),
          Text(
            'No active SOS within 1 km',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(
            height: 7,
          ),
          Text(
            'Pull down to check again.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return ListView.separated(
      physics:
      const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        28,
      ),
      itemCount: _incidents.length,
      separatorBuilder: (
          context,
          index,
          ) {
        return const SizedBox(
          height: 10,
        );
      },
      itemBuilder: (
          context,
          index,
          ) {
        final incident = _incidents[index];

        return _NearbyIncidentCard(
          incident: incident,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (
                    context,
                    ) {
                  return NearbySosDetailScreen(
                    incident: incident,
                  );
                },
              ),
            );

            if (mounted) {
              _load();
            }
          },
        );
      },
    );
  }

  String _cleanError(
      Object error,
      ) {
    return error
        .toString()
        .replaceFirst(
      'Exception: ',
      '',
    );
  }
}

class _NearbyIncidentCard
    extends StatelessWidget {
  final NearbySosIncident incident;

  final VoidCallback onTap;

  const _NearbyIncidentCard({
    required this.incident,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(
                    0x1AFF0000,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sos_rounded,
                  color: Colors.red,
                ),
              ),
              const SizedBox(
                width: 13,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      _categoryName(
                        incident.category,
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      incident.address
                          ?.trim()
                          .isNotEmpty ==
                          true
                          ? incident.address!
                          : 'Emergency location available',
                      maxLines: 2,
                      overflow:
                      TextOverflow.ellipsis,
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      '${_distance(incident.distanceMetres)} away',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _distance(
      double metres,
      ) {
    if (metres < 1000) {
      return '${metres.round()} m';
    }

    return '${(metres / 1000).toStringAsFixed(1)} km';
  }

  String _categoryName(
      String value,
      ) {
    switch (value) {
      case 'medical':
        return 'Medical Emergency';

      case 'crime':
        return 'Crime / Personal Threat';

      case 'accident':
        return 'Accident';

      case 'fire_hazard':
        return 'Fire / Hazard';

      case 'other':
        return 'Other Emergency';

      default:
        return 'Not Sure / Need Help';
    }
  }
}