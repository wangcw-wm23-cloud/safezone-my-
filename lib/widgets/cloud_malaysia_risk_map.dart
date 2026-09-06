import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/malaysia_map_service.dart';
import '../services/state_risk_service.dart';


class CloudMalaysiaRiskMap
    extends StatefulWidget {
  final List<StateRiskData> stateData;

  final String? selectedState;

  final ValueChanged<String>
  onStateSelected;

  const CloudMalaysiaRiskMap({
    super.key,
    required this.stateData,
    required this.selectedState,
    required this.onStateSelected,
  });

  @override
  State<CloudMalaysiaRiskMap>
  createState() =>
      _CloudMalaysiaRiskMapState();
}

class _CloudMalaysiaRiskMapState
    extends State<CloudMalaysiaRiskMap> {
  late Future<MalaysiaMapBoundary>
  _future;

  Size? _cachedSize;

  MalaysiaMapBoundary?
  _cachedBoundary;

  Map<String, Path>
  _projectedPaths = {};

  Map<String, Offset>
  _projectedCentres = {};

  @override
  void initState() {
    super.initState();

    _future =
        MalaysiaMapService.instance
            .load();
  }


  void _retry() {
    setState(() {
      _future =
          MalaysiaMapService.instance
              .load(
            refresh: true,
          );

      _clearProjectionCache();
    });
  }


  void _clearProjectionCache() {
    _cachedSize = null;

    _cachedBoundary = null;

    _projectedPaths = {};

    _projectedCentres = {};
  }

  StateRiskData? _riskFor(
      String state,
      ) {
    for (final item
    in widget.stateData) {
      if (item.state ==
          state) {
        return item;
      }
    }

    return null;
  }

  Color _riskColor(
      String? level,
      ) {
    switch (
    level?.toUpperCase()) {
      case 'VERY HIGH':
        return Colors.red.shade500;

      case 'HIGH':
        return Colors.orange.shade600;

      case 'MODERATE':
        return Colors.amber.shade500;

      case 'LOW':
        return Colors.green.shade500;

      default:
        return Colors.blueGrey.shade300;
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return FutureBuilder<
        MalaysiaMapBoundary>(
      future:
      _future,
      builder: (
          context,
          snapshot,
          ) {

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return _buildLoading();
        }

        if (snapshot.hasError ||
            !snapshot.hasData) {
          return _buildError();
        }

        return _buildMap(
          snapshot.data!,
        );
      },
    );
  }

  Widget _buildLoading() {
    return AspectRatio(
      aspectRatio:
      2.0,
      child: Container(
        decoration:
        BoxDecoration(
          borderRadius:
          BorderRadius.circular(
            18,
          ),
          color:
          Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withOpacity(
            0.35,
          ),
        ),
        child:
        const Center(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2.5,
                ),
              ),

              SizedBox(
                height: 10,
              ),

              Text(
                'Loading Malaysia map...',
                style:
                TextStyle(
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return AspectRatio(
      aspectRatio:
      2.0,
      child: Container(
        decoration:
        BoxDecoration(
          borderRadius:
          BorderRadius.circular(
            18,
          ),
          color:
          Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withOpacity(
            0.35,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              const Icon(
                Icons
                    .map_outlined,
                size: 30,
              ),

              const SizedBox(
                height: 7,
              ),

              const Text(
                'Map unavailable',
                style:
                TextStyle(
                  fontSize: 11,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              TextButton(
                onPressed:
                _retry,
                child:
                const Text(
                  'Retry',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMap(
      MalaysiaMapBoundary boundary,
      ) {
    final scheme =
        Theme.of(context)
            .colorScheme;

    return AspectRatio(

      aspectRatio:
      2.0,
      child: LayoutBuilder(
        builder: (
            context,
            constraints,
            ) {
          final size =
          Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );

          _prepareProjection(
            boundary,
            size,
          );

          final stateColours =
          <String, Color>{};

          for (final state
          in boundary.states) {
            final risk =
            _riskFor(
              state.riskStateName,
            );

            stateColours[
            state.riskStateName] =
                _riskColor(
                  risk?.riskLevel,
                );
          }

          return ClipRRect(
            borderRadius:
            BorderRadius.circular(
              18,
            ),
            child: Container(
              decoration:
              BoxDecoration(
                color: scheme
                    .surfaceContainerHighest
                    .withOpacity(
                  0.28,
                ),
              ),
              child: Stack(
                children: [

                  Positioned.fill(
                    child:
                    GestureDetector(
                      behavior:
                      HitTestBehavior
                          .opaque,
                      onTapDown:
                      _handleTap,
                      child:
                      CustomPaint(
                        isComplex:
                        true,
                        willChange:
                        false,
                        painter:
                        _MalaysiaGeoJsonPainter(
                          paths:
                          _projectedPaths,
                          stateColours:
                          stateColours,
                          selectedState:
                          widget
                              .selectedState,
                          normalBorder:
                          scheme.surface
                              .withOpacity(
                            0.90,
                          ),
                          selectedBorder:
                          scheme.onSurface,
                        ),
                      ),
                    ),
                  ),


                  if (widget
                      .selectedState ==
                      null)
                    Positioned(
                      left: 12,
                      bottom: 10,
                      child: IgnorePointer(
                        child: Container(
                          padding:
                          const EdgeInsets
                              .symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration:
                          BoxDecoration(
                            color: scheme
                                .surface
                                .withOpacity(
                              0.90,
                            ),
                            borderRadius:
                            BorderRadius
                                .circular(
                              20,
                            ),
                            border: Border.all(
                              color: scheme
                                  .outlineVariant,
                            ),
                          ),
                          child:
                          const Row(
                            mainAxisSize:
                            MainAxisSize.min,
                            children: [
                              Icon(
                                Icons
                                    .touch_app_outlined,
                                size: 13,
                              ),

                              SizedBox(
                                width: 5,
                              ),

                              Text(
                                'Tap a state',
                                style:
                                TextStyle(
                                  fontSize: 8,
                                  fontWeight:
                                  FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),


                  if (widget
                      .selectedState !=
                      null)
                    _buildSelectedOverlay(),

                  if (widget
                      .selectedState !=
                      null)
                    _buildPin(
                      widget
                          .selectedState!,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedOverlay() {
    final selected =
    widget.selectedState!;

    final risk =
    _riskFor(
      selected,
    );

    final riskColour =
    _riskColor(
      risk?.riskLevel,
    );

    final scheme =
        Theme.of(context)
            .colorScheme;

    return Positioned(
      left: 12,
      top: 10,
      child: IgnorePointer(
        child:
        AnimatedSwitcher(
          duration:
          const Duration(
            milliseconds: 180,
          ),
          child: Container(
            key:
            ValueKey(
              selected,
            ),
            padding:
            const EdgeInsets
                .fromLTRB(
              10,
              7,
              9,
              7,
            ),
            decoration:
            BoxDecoration(
              color: scheme.surface
                  .withOpacity(
                0.94,
              ),
              borderRadius:
              BorderRadius.circular(
                13,
              ),
              border: Border.all(
                color: scheme
                    .outlineVariant,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withOpacity(
                    0.08,
                  ),
                  blurRadius: 8,
                  offset:
                  const Offset(
                    0,
                    3,
                  ),
                ),
              ],
            ),
            child: Row(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration:
                  BoxDecoration(
                    shape:
                    BoxShape.circle,
                    color:
                    riskColour,
                  ),
                ),

                const SizedBox(
                  width: 7,
                ),

                Text(
                  _shortStateName(
                    selected,
                  ),
                  style:
                  const TextStyle(
                    fontSize: 10,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                if (risk !=
                    null) ...[
                  const SizedBox(
                    width: 8,
                  ),

                  Text(
                    risk.riskLevel,
                    style:
                    TextStyle(
                      fontSize: 8,
                      fontWeight:
                      FontWeight.bold,
                      color:
                      riskColour,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPin(
      String state,
      ) {
    final position =
    _projectedCentres[
    state];

    if (position == null) {
      return const SizedBox
          .shrink();
    }

    final scheme =
        Theme.of(context)
            .colorScheme;

    return Positioned(
      left:
      position.dx -
          13,
      top:
      position.dy -
          30,
      child: IgnorePointer(
        child: Container(
          decoration:
          BoxDecoration(
            shape:
            BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withOpacity(
                  0.22,
                ),
                blurRadius: 8,
                offset:
                const Offset(
                  0,
                  3,
                ),
              ),
            ],
          ),
          child: Icon(
            Icons
                .location_on_rounded,
            size: 29,
            color:
            scheme.primary,
          ),
        ),
      ),
    );
  }

  void _prepareProjection(
      MalaysiaMapBoundary boundary,
      Size size,
      ) {
    if (_cachedBoundary ==
        boundary &&
        _cachedSize ==
            size &&
        _projectedPaths
            .isNotEmpty) {
      return;
    }

    _cachedBoundary =
        boundary;

    _cachedSize =
        size;

    _projectedPaths =
    {};

    _projectedCentres =
    {};

    final bounds =
        boundary.bounds;

    // Internal breathing room.
    final targetRect =
    Rect.fromLTWH(
      14,
      14,
      math.max(
        1,
        size.width - 28,
      ),
      math.max(
        1,
        size.height - 28,
      ),
    );

    final scaleX =
        targetRect.width /
            bounds.longitudeSpan;

    final scaleY =
        targetRect.height /
            bounds.latitudeSpan;

    final scale =
    math.min(
      scaleX,
      scaleY,
    );

    final drawnWidth =
        bounds.longitudeSpan *
            scale;

    final drawnHeight =
        bounds.latitudeSpan *
            scale;

    final offsetX =
        targetRect.left +
            (targetRect.width -
                drawnWidth) /
                2;

    final offsetY =
        targetRect.top +
            (targetRect.height -
                drawnHeight) /
                2;

    Offset project(
        MalaysiaGeoPoint point,
        ) {
      final x =
          offsetX +
              (point.longitude -
                  bounds
                      .minLongitude) *
                  scale;

      final y =
          offsetY +
              (bounds.maxLatitude -
                  point.latitude) *
                  scale;

      return Offset(
        x,
        y,
      );
    }

    Offset projectLonLat(
        double longitude,
        double latitude,
        ) {
      return Offset(
        offsetX +
            (longitude -
                bounds
                    .minLongitude) *
                scale,
        offsetY +
            (bounds.maxLatitude -
                latitude) *
                scale,
      );
    }

    for (final state
    in boundary.states) {
      final statePath =
      Path()
        ..fillType =
            PathFillType
                .evenOdd;

      for (final polygon
      in state.polygons) {
        for (final ring
        in polygon.rings) {
          if (ring.points.isEmpty) {
            continue;
          }

          final first =
          project(
            ring.points.first,
          );

          statePath.moveTo(
            first.dx,
            first.dy,
          );

          for (int i = 1;
          i <
              ring.points.length;
          i++) {
            final position =
            project(
              ring.points[i],
            );

            statePath.lineTo(
              position.dx,
              position.dy,
            );
          }

          statePath.close();
        }
      }

      _projectedPaths[
      state.riskStateName] =
          statePath;

      _projectedCentres[
      state.riskStateName] =
          projectLonLat(
            state.bounds
                .centreLongitude,
            state.bounds
                .centreLatitude,
          );
    }
  }

  void _handleTap(
      TapDownDetails details,
      ) {
    final point =
        details.localPosition;

    const tinyStates = [
      'W.P. Kuala Lumpur',
      'W.P. Putrajaya',
      'W.P. Labuan',
    ];

    for (final state
    in tinyStates) {
      final path =
      _projectedPaths[
      state];

      if (path != null &&
          path.contains(
            point,
          )) {
        widget.onStateSelected(
          state,
        );

        return;
      }
    }

    final entries =
        _projectedPaths.entries
            .toList()
            .reversed;

    for (final entry
    in entries) {
      if (tinyStates.contains(
        entry.key,
      )) {
        continue;
      }

      if (entry.value.contains(
        point,
      )) {
        widget.onStateSelected(
          entry.key,
        );

        return;
      }
    }
  }

  String _shortStateName(
      String state,
      ) {
    switch (state) {
      case 'W.P. Kuala Lumpur':
        return 'Kuala Lumpur';

      case 'W.P. Putrajaya':
        return 'Putrajaya';

      case 'W.P. Labuan':
        return 'Labuan';

      default:
        return state;
    }
  }
}


class _MalaysiaGeoJsonPainter
    extends CustomPainter {
  final Map<String, Path> paths;

  final Map<String, Color>
  stateColours;

  final String? selectedState;

  final Color normalBorder;

  final Color selectedBorder;

  const _MalaysiaGeoJsonPainter({
    required this.paths,
    required this.stateColours,
    required this.selectedState,
    required this.normalBorder,
    required this.selectedBorder,
  });

  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {

    for (final entry
    in paths.entries) {
      if (entry.key ==
          selectedState) {
        continue;
      }

      final baseColour =
          stateColours[
          entry.key] ??
              Colors.grey;

      final alpha =
      selectedState == null
          ? 0.80
          : 0.34;

      final fill =
      Paint()
        ..style =
            PaintingStyle.fill
        ..isAntiAlias =
        true
        ..color =
        baseColour
            .withOpacity(
          alpha,
        );

      final border =
      Paint()
        ..style =
            PaintingStyle.stroke
        ..strokeWidth =
        1.0
        ..strokeJoin =
            StrokeJoin.round
        ..strokeCap =
            StrokeCap.round
        ..isAntiAlias =
        true
        ..color =
            normalBorder;

      canvas.drawPath(
        entry.value,
        fill,
      );

      canvas.drawPath(
        entry.value,
        border,
      );
    }

    if (selectedState != null) {
      final selectedPath =
      paths[
      selectedState];

      if (selectedPath != null) {
        final colour =
            stateColours[
            selectedState] ??
                Colors.grey;

        // Subtle elevation.
        canvas.drawShadow(
          selectedPath,
          Colors.black
              .withOpacity(
            0.22,
          ),
          3.5,
          false,
        );

        final fill =
        Paint()
          ..style =
              PaintingStyle.fill
          ..isAntiAlias =
          true
          ..color =
              colour;

        final border =
        Paint()
          ..style =
              PaintingStyle.stroke
          ..strokeWidth =
          2.7
          ..strokeJoin =
              StrokeJoin.round
          ..strokeCap =
              StrokeCap.round
          ..isAntiAlias =
          true
          ..color =
              selectedBorder;

        canvas.drawPath(
          selectedPath,
          fill,
        );

        canvas.drawPath(
          selectedPath,
          border,
        );
      }
    }
  }

  @override
  bool shouldRepaint(
      covariant
      _MalaysiaGeoJsonPainter
      oldDelegate,
      ) {
    return oldDelegate
        .selectedState !=
        selectedState ||
        oldDelegate
            .stateColours !=
            stateColours ||
        oldDelegate.paths !=
            paths;
  }
}