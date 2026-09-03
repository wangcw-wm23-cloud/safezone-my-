import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/coordination_models.dart';
import '../services/sos_service.dart';

class SosLiveMap extends StatefulWidget {
  final SosIncident incident;

  final List<IncidentHelper> helpers;

  final String? currentUserId;

  const SosLiveMap({
    super.key,
    required this.incident,
    required this.helpers,
    this.currentUserId,
  });

  @override
  State<SosLiveMap> createState() =>
      _SosLiveMapState();
}

class _SosLiveMapState extends State<SosLiveMap>
    with SingleTickerProviderStateMixin {
  final MapController _mapController =
  MapController();

  late final AnimationController
  _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController =
    AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 2400,
      ),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();

    _mapController.dispose();

    super.dispose();
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final sosPoint = LatLng(
      widget.incident.latitude,
      widget.incident.longitude,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 310,
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (
                  context,
                  child,
                  ) {
                final first =
                    _pulseController.value;

                final second =
                    (first + 0.5) % 1.0;

                return FlutterMap(
                  mapController:
                  _mapController,

                  options: MapOptions(
                    initialCenter:
                    sosPoint,

                    initialZoom:
                    16,

                    minZoom:
                    3,

                    maxZoom:
                    19,
                  ),

                  children: [
                    TileLayer(
                      urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

                      userAgentPackageName:
                      'com.safezone.my',
                    ),

                    CircleLayer(
                      circles: [
                        _pulseCircle(
                          sosPoint,
                          first,
                        ),

                        _pulseCircle(
                          sosPoint,
                          second,
                        ),
                      ],
                    ),

                    MarkerLayer(
                      markers: [
                        Marker(
                          point:
                          sosPoint,

                          width:
                          110,

                          height:
                          78,

                          alignment:
                          Alignment.topCenter,

                          child:
                          const _MapPersonMarker(
                            label:
                            'SOS LOCATION',

                            color:
                            Colors.red,

                            icon:
                            Icons.sos_rounded,
                          ),
                        ),

                        ...widget.helpers
                            .where(
                              (
                              helper,
                              ) {
                            return helper
                                .hasLocation;
                          },
                        ).map(
                              (
                              helper,
                              ) {
                            final isCurrentUser =
                                helper.responderId ==
                                    widget.currentUserId;

                            return Marker(
                              point: LatLng(
                                helper.latitude!,
                                helper.longitude!,
                              ),

                              width:
                              120,

                              height:
                              78,

                              alignment:
                              Alignment.topCenter,

                              child:
                              _MapPersonMarker(
                                label:
                                isCurrentUser
                                    ? 'YOU'
                                    : helper.responderName,

                                color:
                                isCurrentUser
                                    ? Colors.indigo
                                    : Colors.green,

                                icon:
                                Icons.person_rounded,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),

            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Theme.of(context)
                    .colorScheme
                    .surface,

                elevation: 3,

                shape:
                const CircleBorder(),

                child: IconButton(
                  tooltip:
                  'Centre SOS location',

                  onPressed: () {
                    _mapController.move(
                      sosPoint,
                      16,
                    );
                  },

                  icon: const Icon(
                    Icons
                        .center_focus_strong_rounded,
                  ),
                ),
              ),
            ),

            Positioned(
              left: 8,
              bottom: 5,
              child: DecoratedBox(
                decoration:
                BoxDecoration(
                  color: Colors.white
                      .withOpacity(
                    0.85,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    4,
                  ),
                ),

                child: const Padding(
                  padding:
                  EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),

                  child: Text(
                    '© OpenStreetMap contributors',

                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  CircleMarker _pulseCircle(
      LatLng point,
      double progress,
      ) {
    return CircleMarker(
      point: point,

      // Pixel animation only.
      // This is not the real 1 km calculation.
      useRadiusInMeter: false,

      radius:
      25 + (105 * progress),

      color:
      Colors.red.withOpacity(
        0.16 * (1 - progress),
      ),

      borderColor:
      Colors.red.withOpacity(
        0.48 * (1 - progress),
      ),

      borderStrokeWidth:
      2,
    );
  }
}

class _MapPersonMarker extends StatelessWidget {
  final String label;

  final Color color;

  final IconData icon;

  const _MapPersonMarker({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Column(
      mainAxisSize:
      MainAxisSize.min,

      children: [
        Container(
          constraints:
          const BoxConstraints(
            maxWidth: 115,
          ),

          padding:
          const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 3,
          ),

          decoration:
          BoxDecoration(
            color: color,

            borderRadius:
            BorderRadius.circular(
              8,
            ),
          ),

          child: Text(
            label,

            maxLines:
            1,

            overflow:
            TextOverflow.ellipsis,

            textAlign:
            TextAlign.center,

            style:
            const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight:
              FontWeight.bold,
            ),
          ),
        ),

        Container(
          width: 38,
          height: 38,

          decoration:
          BoxDecoration(
            color: color,

            shape:
            BoxShape.circle,

            border:
            Border.all(
              color: Colors.white,
              width: 3,
            ),

            boxShadow:
            const [
              BoxShadow(
                color:
                Colors.black26,

                blurRadius:
                5,
              ),
            ],
          ),

          child: Icon(
            icon,
            color: Colors.white,
            size: 21,
          ),
        ),

        Icon(
          Icons.arrow_drop_down,
          color: color,
          size: 22,
        ),
      ],
    );
  }
}