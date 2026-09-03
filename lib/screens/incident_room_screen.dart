import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/coordination_models.dart';
import '../services/emergency_coordination_service.dart';
import '../services/sos_service.dart';
import '../widgets/sos_live_map.dart';
import 'incident_chat_screen.dart';

class IncidentRoomScreen extends StatefulWidget {
  final SosIncident initialIncident;

  final bool isOwner;

  const IncidentRoomScreen({
    super.key,
    required this.initialIncident,
    required this.isOwner,
  });

  @override
  State<IncidentRoomScreen> createState() =>
      _IncidentRoomScreenState();
}

class _IncidentRoomScreenState
    extends State<IncidentRoomScreen> {
  Timer? _locationTimer;

  StreamSubscription<SosIncident?>?
  _incidentSubscription;

  late SosIncident _incident;

  late final Stream<List<IncidentHelper>>
  _helperStream;

  bool _checkingMembership = false;

  bool _joined = false;

  bool _joining = false;

  bool _locationBusy = false;

  bool _closing = false;

  String? _locationError;

  DateTime? _lastLocationUpdate;

  String? get _currentUserId {
    return Supabase
        .instance
        .client
        .auth
        .currentUser
        ?.id;
  }

  bool get _isOpen {
    return _incident.status == 'active' ||
        _incident.status == 'accepted';
  }

  @override
  void initState() {
    super.initState();

    _incident =
        widget.initialIncident;

    _helperStream =
        EmergencyCoordinationService
            .instance
            .streamHelpers(
          _incident.id,
        );

    _incidentSubscription =
        EmergencyCoordinationService
            .instance
            .streamIncident(
          _incident.id,
        ).listen(
              (
              incident,
              ) {
            if (!mounted ||
                incident == null) {
              return;
            }

            setState(() {
              _incident =
                  incident;
            });

            if (!_isOpen) {
              _stopLocationTracking();

              if (!widget.isOwner &&
                  _joined) {
                EmergencyCoordinationService
                    .instance
                    .updateLocalResponseStatus(
                  _incident.id,
                  _incident.status,
                );
              }
            }
          },

          onError: (
              Object error,
              ) {
            debugPrint(
              'INCIDENT REALTIME ERROR: $error',
            );
          },
        );

    if (widget.isOwner) {
      _joined =
      true;

      _startLocationTracking();
    } else {
      _checkMembership();
    }
  }

  Future<void> _checkMembership() async {
    setState(() {
      _checkingMembership =
      true;
    });

    try {
      final response =
      await EmergencyCoordinationService
          .instance
          .getMyResponse(
        _incident.id,
      );

      final joined =
          response?.status ==
              'accepted';

      if (!mounted) return;

      setState(() {
        _joined =
            joined;
      });

      if (joined) {
        _startLocationTracking();
      }
    } catch (e) {
      debugPrint(
        'CHECK HELPER MEMBERSHIP ERROR: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _checkingMembership =
          false;
        });
      }
    }
  }

  void _startLocationTracking() {
    _locationTimer?.cancel();

    _updateMyLocation();

    _locationTimer =
        Timer.periodic(
          const Duration(
            seconds: 15,
          ),
              (
              timer,
              ) {
            _updateMyLocation();
          },
        );
  }

  void _stopLocationTracking() {
    _locationTimer?.cancel();

    _locationTimer =
    null;
  }

  Future<void> _updateMyLocation() async {
    if (_locationBusy ||
        _closing ||
        !_isOpen) {
      return;
    }

    if (!widget.isOwner &&
        !_joined) {
      return;
    }

    _locationBusy =
    true;

    if (mounted) {
      setState(() {
        _locationError =
        null;
      });
    }

    try {
      if (widget.isOwner) {
        await SosService.instance
            .updateLiveLocation(
          _incident.id,
        );
      } else {
        await EmergencyCoordinationService
            .instance
            .updateHelperLocation(
          _incident.id,
        );
      }

      if (!mounted) return;

      setState(() {
        _lastLocationUpdate =
            DateTime.now();
      });
    } catch (e) {
      debugPrint(
        'LIVE LOCATION ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        _locationError =
            _cleanError(e);
      });
    } finally {
      _locationBusy =
      false;

      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _join() async {
    if (_joining ||
        !_isOpen) {
      return;
    }

    setState(() {
      _joining =
      true;
    });

    try {
      await EmergencyCoordinationService
          .instance
          .joinIncident(
        incidentId:
        _incident.id,

        category:
        _incident.category,

        latitude:
        _incident.latitude,

        longitude:
        _incident.longitude,

        address:
        _incident.address,
      );

      if (!mounted) return;

      setState(() {
        _joined =
        true;
      });

      _startLocationTracking();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'You joined this SOS. Your live location is now shared.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _showError(e);
    } finally {
      if (mounted) {
        setState(() {
          _joining =
          false;
        });
      }
    }
  }

  Future<void> _leave() async {
    final confirmed =
    await _confirm(
      title:
      'Leave this SOS?',

      message:
      'You will be removed from the helper map and your location sharing will stop.',

      action:
      'Leave',

      destructive:
      true,
    );

    if (!confirmed) {
      return;
    }

    setState(() {
      _closing =
      true;
    });

    try {
      await EmergencyCoordinationService
          .instance
          .leaveIncident(
        _incident.id,
      );

      _stopLocationTracking();

      if (!mounted) return;

      setState(() {
        _joined =
        false;
      });

      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        _showError(e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _closing =
          false;
        });
      }
    }
  }

  Future<void> _resolve() async {
    final confirmed =
    await _confirm(
      title:
      'Are you safe now?',

      message:
      'This will end live location sharing and make the chat read-only.',

      action:
      'I Am Safe',
    );

    if (!confirmed) {
      return;
    }

    await _finishOwnerIncident(
      resolved:
      true,
    );
  }

  Future<void> _cancel() async {
    final confirmed =
    await _confirm(
      title:
      'Cancel SOS?',

      message:
      'Only cancel if this alert was sent accidentally.',

      action:
      'Cancel SOS',

      destructive:
      true,
    );

    if (!confirmed) {
      return;
    }

    await _finishOwnerIncident(
      resolved:
      false,
    );
  }

  Future<void> _finishOwnerIncident({
    required bool resolved,
  }) async {
    setState(() {
      _closing =
      true;
    });

    try {
      if (resolved) {
        await SosService.instance
            .resolveSos(
          _incident.id,
        );
      } else {
        await SosService.instance
            .cancelSos(
          _incident.id,
        );
      }

      _stopLocationTracking();

      if (!mounted) return;

      Navigator.popUntil(
        context,
            (
            route,
            ) {
          return route.isFirst;
        },
      );
    } catch (e) {
      if (mounted) {
        _showError(e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _closing =
          false;
        });
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (
          dialogContext,
          ) {
        return AlertDialog(
          title:
          Text(title),

          content:
          Text(message),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },

              child:
              const Text(
                'Back',
              ),
            ),

            FilledButton(
              style:
              destructive
                  ? FilledButton.styleFrom(
                backgroundColor:
                Colors.red,
              )
                  : null,

              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },

              child:
              Text(action),
            ),
          ],
        );
      },
    ) ??
        false;
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (
            context,
            ) {
          return IncidentChatScreen(
            incidentId:
            _incident.id,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _stopLocationTracking();

    _incidentSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return PopScope(
      canPop:
      !widget.isOwner,

      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading:
          !widget.isOwner,

          title: Text(
            widget.isOwner
                ? 'SOS Active'
                : 'SOS Details',
          ),

          actions: [
            if ((widget.isOwner ||
                _joined) &&
                _isOpen)
              IconButton(
                tooltip:
                'Emergency chat',

                onPressed:
                _openChat,

                icon:
                const Icon(
                  Icons.forum_outlined,
                ),
              ),
          ],
        ),

        body: StreamBuilder<
            List<IncidentHelper>>(
          stream:
          _helperStream,

          initialData:
          const [],

          builder: (
              context,
              snapshot,
              ) {
            final helpers =
                snapshot.data ??
                    const <
                        IncidentHelper>[];

            return ListView(
              padding:
              const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                28,
              ),

              children: [
                _StatusBanner(
                  status:
                  _incident.status,
                ),

                const SizedBox(
                  height: 12,
                ),

                SosLiveMap(
                  incident:
                  _incident,

                  helpers:
                  helpers,

                  currentUserId:
                  _currentUserId,
                ),

                const SizedBox(
                  height: 12,
                ),

                _IncidentSummary(
                  incident:
                  _incident,
                ),

                const SizedBox(
                  height: 12,
                ),

                _HelperCard(
                  helpers:
                  helpers,

                  onChat:
                  _openChat,

                  chatEnabled:
                  widget.isOwner ||
                      _joined,
                ),

                const SizedBox(
                  height: 12,
                ),

                _LocationCard(
                  busy:
                  _locationBusy,

                  joined:
                  widget.isOwner ||
                      _joined,

                  lastUpdate:
                  _lastLocationUpdate,

                  error:
                  _locationError,
                ),

                const SizedBox(
                  height: 22,
                ),

                if (_isOpen)
                  _buildActions(),

                if (!_isOpen)
                  const Card(
                    child: Padding(
                      padding:
                      EdgeInsets.all(
                        18,
                      ),

                      child: Text(
                        'This emergency has ended. Live location sharing is stopped and the chat is read-only.',

                        textAlign:
                        TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildActions() {
    if (_checkingMembership) {
      return const Center(
        child:
        CircularProgressIndicator(),
      );
    }

    if (!widget.isOwner &&
        !_joined) {
      return SizedBox(
        height: 54,

        child: FilledButton.icon(
          onPressed:
          _joining
              ? null
              : _join,

          icon:
          _joining
              ? const SizedBox(
            width: 20,
            height: 20,

            child:
            CircularProgressIndicator(
              strokeWidth:
              2,
            ),
          )
              : const Icon(
            Icons
                .volunteer_activism_rounded,
          ),

          label:
          const Text(
            'I CAN HELP',
          ),
        ),
      );
    }

    if (!widget.isOwner) {
      return Column(
        children: [
          SizedBox(
            width:
            double.infinity,

            height:
            52,

            child:
            FilledButton.icon(
              onPressed:
              _openChat,

              icon:
              const Icon(
                Icons.forum_rounded,
              ),

              label:
              const Text(
                'OPEN EMERGENCY CHAT',
              ),
            ),
          ),

          const SizedBox(
            height: 9,
          ),

          SizedBox(
            width:
            double.infinity,

            height:
            48,

            child:
            OutlinedButton.icon(
              onPressed:
              _closing
                  ? null
                  : _leave,

              icon:
              const Icon(
                Icons.exit_to_app_rounded,
              ),

              label:
              const Text(
                'Leave Help Team',
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(
          width:
          double.infinity,

          height:
          52,

          child:
          FilledButton.icon(
            onPressed:
            _closing
                ? null
                : _resolve,

            icon:
            const Icon(
              Icons.verified_user_rounded,
            ),

            label:
            const Text(
              "I'M SAFE NOW",
            ),
          ),
        ),

        const SizedBox(
          height: 9,
        ),

        SizedBox(
          width:
          double.infinity,

          height:
          48,

          child:
          OutlinedButton.icon(
            onPressed:
            _closing
                ? null
                : _cancel,

            icon:
            const Icon(
              Icons.cancel_outlined,
            ),

            label:
            const Text(
              'Cancel SOS',
            ),
          ),
        ),
      ],
    );
  }

  void _showError(
      Object error,
      ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          _cleanError(error),
        ),
      ),
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

class _StatusBanner extends StatelessWidget {
  final String status;

  const _StatusBanner({
    required this.status,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final active =
        status == 'active' ||
            status == 'accepted';

    final hasHelper =
        status == 'accepted';

    final color =
    active
        ? Colors.red
        : Colors.grey;

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),

      decoration:
      BoxDecoration(
        color:
        color.withOpacity(
          0.09,
        ),

        borderRadius:
        BorderRadius.circular(
          14,
        ),

        border:
        Border.all(
          color:
          color.withOpacity(
            0.25,
          ),
        ),
      ),

      child: Row(
        children: [
          Icon(
            active
                ? Icons.sensors_rounded
                : Icons
                .check_circle_outline,

            color:
            color,
          ),

          const SizedBox(
            width: 9,
          ),

          Expanded(
            child: Text(
              !active
                  ? 'SOS ${status.toUpperCase()}'
                  : hasHelper
                  ? 'HELPERS ARE RESPONDING'
                  : 'SOS ALERT IS LIVE',

              style: TextStyle(
                color:
                color,

                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncidentSummary extends StatelessWidget {
  final SosIncident incident;

  const _IncidentSummary({
    required this.incident,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(
          15,
        ),

        child: Column(
          children: [
            _row(
              Icons.warning_amber_rounded,
              'Emergency',
              _categoryName(
                incident.category,
              ),
            ),

            const Divider(
              height: 24,
            ),

            _row(
              Icons.location_on_outlined,
              'Location',

              incident.address
                  ?.trim()
                  .isNotEmpty ==
                  true
                  ? incident.address!
                  : '${incident.latitude.toStringAsFixed(5)}, '
                  '${incident.longitude.toStringAsFixed(5)}',
            ),

            const Divider(
              height: 24,
            ),

            _row(
              Icons.schedule_rounded,
              'Started',
              _dateTime(
                incident.createdAt,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
      IconData icon,
      String label,
      String value,
      ) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        Icon(
          icon,
          size: 22,
        ),

        const SizedBox(
          width: 11,
        ),

        SizedBox(
          width: 72,

          child: Text(
            label,

            style:
            const TextStyle(
              fontSize: 12,
            ),
          ),
        ),

        Expanded(
          child: Text(
            value,

            style:
            const TextStyle(
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _dateTime(
      DateTime value,
      ) {
    final local =
    value.toLocal();

    final minute =
    local.minute
        .toString()
        .padLeft(
      2,
      '0',
    );

    return '${local.day}/${local.month}/${local.year}  '
        '${local.hour}:$minute';
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

class _HelperCard extends StatelessWidget {
  final List<IncidentHelper> helpers;

  final VoidCallback onChat;

  final bool chatEnabled;

  const _HelperCard({
    required this.helpers,
    required this.onChat,
    required this.chatEnabled,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final count =
        helpers.length;

    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(
          15,
        ),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                const Icon(
                  Icons.groups_rounded,
                  color: Colors.green,
                ),

                const SizedBox(
                  width: 10,
                ),

                Expanded(
                  child: Text(
                    count == 1
                        ? '1 person joined to help'
                        : '$count people joined to help',

                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),

                IconButton(
                  tooltip:
                  'Open chat',

                  onPressed:
                  chatEnabled
                      ? onChat
                      : null,

                  icon:
                  const Icon(
                    Icons.forum_outlined,
                  ),
                ),
              ],
            ),

            if (helpers.isEmpty)
              const Padding(
                padding:
                EdgeInsets.only(
                  top: 5,
                ),

                child: Text(
                  'Waiting for nearby SafeZone users to respond.',
                ),
              )
            else
              Wrap(
                spacing:
                7,

                runSpacing:
                7,

                children: helpers
                    .map(
                      (
                      helper,
                      ) {
                    return Chip(
                      avatar: Icon(
                        helper.hasLocation
                            ? Icons
                            .location_on_rounded
                            : Icons
                            .location_off_rounded,

                        size:
                        17,
                      ),

                      label: Text(
                        helper
                            .responderName,
                      ),
                    );
                  },
                ).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final bool busy;

  final bool joined;

  final DateTime? lastUpdate;

  final String? error;

  const _LocationCard({
    required this.busy,
    required this.joined,
    required this.lastUpdate,
    required this.error,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final failed =
        error != null;

    final color =
    failed
        ? Colors.orange
        : Colors.blue;

    return Container(
      padding:
      const EdgeInsets.all(
        14,
      ),

      decoration:
      BoxDecoration(
        color:
        color.withOpacity(
          0.07,
        ),

        borderRadius:
        BorderRadius.circular(
          15,
        ),

        border:
        Border.all(
          color:
          color.withOpacity(
            0.2,
          ),
        ),
      ),

      child: Row(
        children: [
          Icon(
            failed
                ? Icons.location_off_rounded
                : Icons.my_location_rounded,

            color:
            color,
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Text(
                  joined
                      ? 'Live Location Sharing'
                      : 'Location sharing starts after joining',

                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  failed
                      ? error!
                      : lastUpdate == null
                      ? joined
                      ? 'Preparing location...'
                      : 'Press I CAN HELP to join'
                      : 'Updated at ${_clock(lastUpdate!)}',

                  style:
                  const TextStyle(
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          if (busy)
            const SizedBox(
              width: 18,
              height: 18,

              child:
              CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
        ],
      ),
    );
  }

  String _clock(
      DateTime value,
      ) {
    final local =
    value.toLocal();

    final minute =
    local.minute
        .toString()
        .padLeft(
      2,
      '0',
    );

    final second =
    local.second
        .toString()
        .padLeft(
      2,
      '0',
    );

    return '${local.hour}:$minute:$second';
  }
}