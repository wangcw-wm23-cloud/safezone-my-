import 'package:flutter/material.dart';

import '../services/sos_service.dart';
import 'active_sos_screen.dart';

// ============================================================
// SOS SCREEN
//
// User selects one emergency category,
// then presses SEND SOS.
//
// No additional confirmation screen.
// ============================================================

class SosScreen extends StatefulWidget {
  const SosScreen({
    super.key,
  });

  @override
  State<SosScreen> createState() =>
      _SosScreenState();
}

class _SosScreenState
    extends State<SosScreen> {
  String _selectedCategory =
      'unsure';

  bool _sending = false;

  // ============================================================
  // CATEGORIES
  // ============================================================

  final List<_SosCategoryOption>
  _categories = const [
    _SosCategoryOption(
      value:
      'medical',
      title:
      'Medical Emergency',
      subtitle:
      'Serious illness, injury or urgent medical help',
      icon:
      Icons.medical_services_outlined,
      color:
      Colors.redAccent,
    ),

    _SosCategoryOption(
      value:
      'crime',
      title:
      'Crime / Personal Threat',
      subtitle:
      'Crime, violence, harassment or immediate threat',
      icon:
      Icons.shield_outlined,
      color:
      Colors.deepOrange,
    ),

    _SosCategoryOption(
      value:
      'accident',
      title:
      'Accident',
      subtitle:
      'Road accident or other serious accident',
      icon:
      Icons.car_crash_outlined,
      color:
      Colors.blue,
    ),

    _SosCategoryOption(
      value:
      'fire_hazard',
      title:
      'Fire / Hazard',
      subtitle:
      'Fire, smoke or another dangerous hazard',
      icon:
      Icons.local_fire_department_outlined,
      color:
      Colors.orange,
    ),

    _SosCategoryOption(
      value:
      'other',
      title:
      'Other Emergency',
      subtitle:
      'Another emergency situation requiring assistance',
      icon:
      Icons.warning_amber_rounded,
      color:
      Colors.purple,
    ),

    _SosCategoryOption(
      value:
      'unsure',
      title:
      'Not Sure / Need Help',
      subtitle:
      'Use this if you are unsure which category applies',
      icon:
      Icons.sos_rounded,
      color:
      Colors.red,
    ),
  ];

  // ============================================================
  // SEND SOS
  // ============================================================

  Future<void> _sendSos() async {
    if (_sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      final incident =
      await SosService.instance
          .createSos(
        category:
        _selectedCategory,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ActiveSosScreen(
                incident:
                incident,
              ),
        ),
      );
    } catch (e) {
      debugPrint(
        'SEND SOS ERROR: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
          Text(
            _cleanError(
              e,
            ),
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      appBar:
      AppBar(
        title:
        const Text(
          'Emergency SOS',
        ),
      ),
      body:
      SafeArea(
        child:
        Column(
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Padding(
              padding:
              const EdgeInsets.fromLTRB(
                20,
                12,
                20,
                16,
              ),
              child:
              Column(
                children: [
                  Container(
                    width:
                    66,
                    height:
                    66,
                    decoration:
                    BoxDecoration(
                      shape:
                      BoxShape.circle,
                      color:
                      Colors.red.withOpacity(
                        0.10,
                      ),
                    ),
                    child:
                    const Icon(
                      Icons
                          .sos_rounded,
                      color:
                      Colors.redAccent,
                      size:
                      36,
                    ),
                  ),

                  const SizedBox(
                    height:
                    13,
                  ),

                  const Text(
                    'What kind of help do you need?',
                    textAlign:
                    TextAlign.center,
                    style:
                    TextStyle(
                      fontSize:
                      20,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height:
                    5,
                  ),

                  const Text(
                    'Choose the closest option. If you are unsure, select Not Sure / Need Help.',
                    textAlign:
                    TextAlign.center,
                    style:
                    TextStyle(
                      fontSize:
                      10,
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // CATEGORY LIST
            // ==================================================

            Expanded(
              child:
              ListView.separated(
                padding:
                const EdgeInsets.symmetric(
                  horizontal:
                  18,
                ),

                itemCount:
                _categories.length,

                separatorBuilder: (
                    context,
                    index,
                    ) =>
                const SizedBox(
                  height:
                  9,
                ),

                itemBuilder: (
                    context,
                    index,
                    ) {
                  final option =
                  _categories[
                  index];

                  return _buildCategory(
                    option,
                  );
                },
              ),
            ),

            // ==================================================
            // SEND BUTTON
            // ==================================================

            Container(
              padding:
              const EdgeInsets.fromLTRB(
                18,
                13,
                18,
                18,
              ),
              decoration:
              BoxDecoration(
                color:
                Theme.of(context)
                    .colorScheme
                    .surface,
                border:
                Border(
                  top:
                  BorderSide(
                    color:
                    Theme.of(context)
                        .colorScheme
                        .outlineVariant,
                  ),
                ),
              ),
              child:
              Column(
                children: [
                  const Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons
                            .my_location_rounded,
                        size:
                        15,
                      ),

                      SizedBox(
                        width:
                        5,
                      ),

                      Text(
                        'Your current GPS location will be attached automatically.',
                        style:
                        TextStyle(
                          fontSize:
                          8,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height:
                    11,
                  ),

                  SizedBox(
                    width:
                    double.infinity,
                    height:
                    56,
                    child:
                    FilledButton.icon(
                      style:
                      FilledButton.styleFrom(
                        backgroundColor:
                        Colors.redAccent,
                        foregroundColor:
                        Colors.white,
                      ),
                      onPressed:
                      _sending
                          ? null
                          : _sendSos,
                      icon:
                      _sending
                          ? const SizedBox(
                        width:
                        20,
                        height:
                        20,
                        child:
                        CircularProgressIndicator(
                          strokeWidth:
                          2,
                          color:
                          Colors.white,
                        ),
                      )
                          : const Icon(
                        Icons
                            .sos_rounded,
                      ),
                      label:
                      Text(
                        _sending
                            ? 'SENDING SOS...'
                            : 'SEND SOS',
                        style:
                        const TextStyle(
                          fontWeight:
                          FontWeight.bold,
                          fontSize:
                          16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CATEGORY
  // ============================================================

  Widget _buildCategory(
      _SosCategoryOption option,
      ) {
    final selected =
        _selectedCategory ==
            option.value;

    return Material(
      color:
      Colors.transparent,
      child:
      InkWell(
        borderRadius:
        BorderRadius.circular(
          17,
        ),
        onTap:
        _sending
            ? null
            : () {
          setState(() {
            _selectedCategory =
                option.value;
          });
        },
        child:
        AnimatedContainer(
          duration:
          const Duration(
            milliseconds:
            150,
          ),
          padding:
          const EdgeInsets.all(
            14,
          ),
          decoration:
          BoxDecoration(
            borderRadius:
            BorderRadius.circular(
              17,
            ),
            color:
            selected
                ? option.color
                .withOpacity(
              0.10,
            )
                : Theme.of(context)
                .colorScheme
                .surfaceContainer,
            border:
            Border.all(
              color:
              selected
                  ? option.color
                  : Theme.of(context)
                  .colorScheme
                  .outlineVariant,
              width:
              selected
                  ? 1.6
                  : 1,
            ),
          ),
          child:
          Row(
            children: [
              Container(
                width:
                44,
                height:
                44,
                decoration:
                BoxDecoration(
                  borderRadius:
                  BorderRadius.circular(
                    13,
                  ),
                  color:
                  option.color
                      .withOpacity(
                    0.12,
                  ),
                ),
                child:
                Icon(
                  option.icon,
                  color:
                  option.color,
                  size:
                  22,
                ),
              ),

              const SizedBox(
                width:
                12,
              ),

              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style:
                      const TextStyle(
                        fontSize:
                        12,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height:
                      3,
                    ),

                    Text(
                      option.subtitle,
                      style:
                      const TextStyle(
                        fontSize:
                        8.5,
                        height:
                        1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width:
                8,
              ),

              Icon(
                selected
                    ? Icons
                    .radio_button_checked_rounded
                    : Icons
                    .radio_button_off_rounded,
                color:
                selected
                    ? option.color
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CATEGORY OPTION
// ============================================================

class _SosCategoryOption {
  final String value;

  final String title;

  final String subtitle;

  final IconData icon;

  final Color color;

  const _SosCategoryOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}