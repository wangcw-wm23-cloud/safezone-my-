import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/coordination_models.dart';
import '../services/emergency_coordination_service.dart';
import '../services/sos_service.dart';

class IncidentChatScreen extends StatefulWidget {
  final String incidentId;

  const IncidentChatScreen({
    super.key,
    required this.incidentId,
  });

  @override
  State<IncidentChatScreen> createState() =>
      _IncidentChatScreenState();
}

class _IncidentChatScreenState
    extends State<IncidentChatScreen> {
  final TextEditingController
  _messageController =
  TextEditingController();

  final ScrollController
  _scrollController =
  ScrollController();

  late final Stream<List<IncidentMessage>>
  _messageStream;

  late final Stream<SosIncident?>
  _incidentStream;

  bool _sending = false;

  String? get _currentUserId {
    return Supabase
        .instance
        .client
        .auth
        .currentUser
        ?.id;
  }

  @override
  void initState() {
    super.initState();

    _messageStream =
        EmergencyCoordinationService
            .instance
            .streamMessages(
          widget.incidentId,
        );

    _incidentStream =
        EmergencyCoordinationService
            .instance
            .streamIncident(
          widget.incidentId,
        );
  }

  @override
  void dispose() {
    _messageController.dispose();

    _scrollController.dispose();

    super.dispose();
  }

  Future<void> _send() async {
    if (_sending ||
        _messageController.text
            .trim()
            .isEmpty) {
      return;
    }

    final text =
    _messageController.text.trim();

    setState(() {
      _sending = true;
    });

    try {
      await EmergencyCoordinationService
          .instance
          .sendMessage(
        incidentId:
        widget.incidentId,

        message:
        text,
      );

      _messageController.clear();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            _cleanError(e),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return StreamBuilder<SosIncident?>(
      stream:
      _incidentStream,

      builder: (
          context,
          incidentSnapshot,
          ) {
        final status =
            incidentSnapshot
                .data
                ?.status ??
                'active';

        final roomOpen =
            status == 'active' ||
                status == 'accepted';

        return Scaffold(
          appBar: AppBar(
            title: const Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Text(
                  'Emergency Chat',
                ),

                Text(
                  'Temporary coordination room',

                  style: TextStyle(
                    fontSize: 11,

                    fontWeight:
                    FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),

          body: Column(
            children: [
              if (!roomOpen)
                Container(
                  width:
                  double.infinity,

                  padding:
                  const EdgeInsets.all(
                    10,
                  ),

                  color: Colors.orange
                      .withOpacity(
                    0.12,
                  ),

                  child: const Text(
                    'This SOS has ended. The chat is now read-only.',

                    textAlign:
                    TextAlign.center,
                  ),
                ),

              Expanded(
                child: StreamBuilder<
                    List<IncidentMessage>>(
                  stream:
                  _messageStream,

                  builder: (
                      context,
                      snapshot,
                      ) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Unable to load chat: ${snapshot.error}',
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child:
                        CircularProgressIndicator(),
                      );
                    }

                    final messages =
                    snapshot.data!;

                    WidgetsBinding
                        .instance
                        .addPostFrameCallback(
                          (
                          _,
                          ) {
                        if (_scrollController
                            .hasClients) {
                          _scrollController
                              .animateTo(
                            _scrollController
                                .position
                                .maxScrollExtent,

                            duration:
                            const Duration(
                              milliseconds:
                              220,
                            ),

                            curve:
                            Curves.easeOut,
                          );
                        }
                      },
                    );

                    if (messages.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding:
                          EdgeInsets.all(
                            30,
                          ),

                          child: Text(
                            'No messages yet.\n'
                                'Use this room to coordinate help.',

                            textAlign:
                            TextAlign.center,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller:
                      _scrollController,

                      padding:
                      const EdgeInsets.all(
                        16,
                      ),

                      itemCount:
                      messages.length,

                      itemBuilder: (
                          context,
                          index,
                          ) {
                        final message =
                        messages[index];

                        return _MessageBubble(
                          message:
                          message,

                          mine:
                          message.senderId ==
                              _currentUserId,
                        );
                      },
                    );
                  },
                ),
              ),

              if (roomOpen)
                SafeArea(
                  top: false,

                  child: Padding(
                    padding:
                    const EdgeInsets.fromLTRB(
                      12,
                      8,
                      12,
                      12,
                    ),

                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller:
                            _messageController,

                            minLines:
                            1,

                            maxLines:
                            4,

                            maxLength:
                            500,

                            textCapitalization:
                            TextCapitalization
                                .sentences,

                            decoration:
                            const InputDecoration(
                              hintText:
                              'Type a message...',

                              counterText:
                              '',

                              border:
                              OutlineInputBorder(),
                            ),

                            onSubmitted:
                                (
                                _,
                                ) {
                              _send();
                            },
                          ),
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        IconButton.filled(
                          onPressed:
                          _sending
                              ? null
                              : _send,

                          icon:
                          _sending
                              ? const SizedBox(
                            width:
                            19,

                            height:
                            19,

                            child:
                            CircularProgressIndicator(
                              strokeWidth:
                              2,
                            ),
                          )
                              : const Icon(
                            Icons
                                .send_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
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

class _MessageBubble extends StatelessWidget {
  final IncidentMessage message;

  final bool mine;

  const _MessageBubble({
    required this.message,
    required this.mine,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final color =
    mine
        ? Theme.of(context)
        .colorScheme
        .primary
        : Theme.of(context)
        .colorScheme
        .surfaceContainerHighest;

    final textColor =
    mine
        ? Theme.of(context)
        .colorScheme
        .onPrimary
        : Theme.of(context)
        .colorScheme
        .onSurface;

    return Align(
      alignment:
      mine
          ? Alignment.centerRight
          : Alignment.centerLeft,

      child: Container(
        constraints:
        const BoxConstraints(
          maxWidth: 290,
        ),

        margin:
        const EdgeInsets.only(
          bottom: 10,
        ),

        padding:
        const EdgeInsets.fromLTRB(
          12,
          8,
          12,
          7,
        ),

        decoration:
        BoxDecoration(
          color:
          color,

          borderRadius:
          BorderRadius.circular(
            15,
          ),
        ),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            if (!mine)
              Padding(
                padding:
                const EdgeInsets.only(
                  bottom: 3,
                ),

                child: Text(
                  message.senderName,

                  style: TextStyle(
                    color:
                    textColor,

                    fontSize:
                    11,

                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),

            Text(
              message.message,

              style: TextStyle(
                color:
                textColor,
              ),
            ),

            const SizedBox(
              height: 3,
            ),

            Text(
              _time(
                message.createdAt,
              ),

              style: TextStyle(
                color:
                textColor.withOpacity(
                  0.7,
                ),

                fontSize:
                9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _time(
      DateTime value,
      ) {
    final local =
    value.toLocal();

    final hour =
    local.hour
        .toString()
        .padLeft(
      2,
      '0',
    );

    final minute =
    local.minute
        .toString()
        .padLeft(
      2,
      '0',
    );

    return '$hour:$minute';
  }
}