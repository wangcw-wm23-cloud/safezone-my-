import 'package:flutter/material.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  // ============================================================
  // DEFAULT CATEGORY
  //
  // User can immediately send SOS without spending time
  // deciding which emergency category applies.
  // ============================================================

  SosCategory _selectedCategory = SosCategory.unsure;

  bool _isSending = false;

  // ============================================================
  // SELECT CATEGORY
  // ============================================================

  void _selectCategory(
      SosCategory category,
      ) {
    setState(() {
      _selectedCategory = category;
    });
  }

  // ============================================================
  // SEND SOS
  //
  // GPS + Supabase backend will be connected later.
  // ============================================================

  Future<void> _sendSos() async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      // ========================================================
      // FUTURE IMPLEMENTATION
      //
      // 1. Get current GPS
      // 2. Create sos_incidents record
      // 3. Save category
      // 4. Broadcast to nearby SafeZone users
      // 5. Start live location tracking
      //
      // Example:
      //
      // await supabase.from('sos_incidents').insert({
      //   'user_id': user.id,
      //   'category': _selectedCategory.code,
      //   'latitude': position.latitude,
      //   'longitude': position.longitude,
      //   'status': 'active',
      // });
      // ========================================================

      debugPrint(
        'SOS CATEGORY: ${_selectedCategory.code}',
      );

      await Future.delayed(
        const Duration(
          milliseconds: 500,
        ),
      );

      if (!mounted) return;

      // ========================================================
      // TEMPORARY SUCCESS MESSAGE
      //
      // Remove this when real SOS backend is connected.
      // ========================================================

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.sos_rounded,
              color: Colors.red,
              size: 52,
            ),
            title: const Text(
              'SOS Activated',
              textAlign: TextAlign.center,
            ),
            content: Text(
              '${_selectedCategory.label}\n\n'
                  'The SOS backend, live location and nearby-user '
                  'broadcast will be connected in the next stage.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment:
            MainAxisAlignment.center,
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                  );
                },
                child: const Text(
                  'OK',
                ),
              ),
            ],
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Emergency SOS',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // SCROLLABLE CONTENT
            // ==================================================

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  20,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,
                  children: [
                    // ==========================================
                    // HEADER
                    // ==========================================

                    Container(
                      padding:
                      const EdgeInsets.all(
                        20,
                      ),
                      decoration: BoxDecoration(
                        borderRadius:
                        BorderRadius.circular(
                          22,
                        ),
                        color: Colors.red
                            .withOpacity(
                          0.08,
                        ),
                        border: Border.all(
                          color: Colors.red
                              .withOpacity(
                            0.25,
                          ),
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.sos_rounded,
                            color: Colors.red,
                            size: 58,
                          ),

                          SizedBox(
                            height: 10,
                          ),

                          Text(
                            'Emergency Assistance',
                            textAlign:
                            TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),

                          SizedBox(
                            height: 7,
                          ),

                          Text(
                            'Choose the emergency type if possible, '
                                'then send your SOS alert.',
                            textAlign:
                            TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 24,
                    ),

                    // ==========================================
                    // CATEGORY TITLE
                    // ==========================================

                    const Text(
                      'Emergency Type',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    const Text(
                      'Select the option that best describes your situation.',
                      style: TextStyle(
                        fontSize: 11,
                      ),
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    // ==========================================
                    // MEDICAL
                    // ==========================================

                    _SosCategoryCard(
                      category:
                      SosCategory.medical,
                      selected:
                      _selectedCategory ==
                          SosCategory
                              .medical,
                      onTap: () {
                        _selectCategory(
                          SosCategory.medical,
                        );
                      },
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ==========================================
                    // CRIME
                    // ==========================================

                    _SosCategoryCard(
                      category:
                      SosCategory.crime,
                      selected:
                      _selectedCategory ==
                          SosCategory.crime,
                      onTap: () {
                        _selectCategory(
                          SosCategory.crime,
                        );
                      },
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ==========================================
                    // ACCIDENT
                    // ==========================================

                    _SosCategoryCard(
                      category:
                      SosCategory.accident,
                      selected:
                      _selectedCategory ==
                          SosCategory
                              .accident,
                      onTap: () {
                        _selectCategory(
                          SosCategory.accident,
                        );
                      },
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ==========================================
                    // FIRE / HAZARD
                    // ==========================================

                    _SosCategoryCard(
                      category:
                      SosCategory.fireHazard,
                      selected:
                      _selectedCategory ==
                          SosCategory
                              .fireHazard,
                      onTap: () {
                        _selectCategory(
                          SosCategory
                              .fireHazard,
                        );
                      },
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ==========================================
                    // OTHER
                    // ==========================================

                    _SosCategoryCard(
                      category:
                      SosCategory.other,
                      selected:
                      _selectedCategory ==
                          SosCategory.other,
                      onTap: () {
                        _selectCategory(
                          SosCategory.other,
                        );
                      },
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ==========================================
                    // NOT SURE
                    // ==========================================

                    _SosCategoryCard(
                      category:
                      SosCategory.unsure,
                      selected:
                      _selectedCategory ==
                          SosCategory.unsure,
                      onTap: () {
                        _selectCategory(
                          SosCategory.unsure,
                        );
                      },
                    ),

                    const SizedBox(
                      height: 22,
                    ),

                    // ==========================================
                    // WHAT WILL HAPPEN
                    // ==========================================

                    Container(
                      padding:
                      const EdgeInsets.all(
                        17,
                      ),
                      decoration: BoxDecoration(
                        borderRadius:
                        BorderRadius.circular(
                          18,
                        ),
                        color: colorScheme
                            .surfaceContainer,
                        border: Border.all(
                          color: colorScheme
                              .outlineVariant,
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Text(
                            'When you send SOS',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),

                          SizedBox(
                            height: 14,
                          ),

                          _SosInformationRow(
                            icon: Icons
                                .location_on_outlined,
                            text:
                            'Your current location will be shared.',
                          ),

                          SizedBox(
                            height: 13,
                          ),

                          _SosInformationRow(
                            icon: Icons
                                .people_outline_rounded,
                            text:
                            'Eligible SafeZone users nearby may receive your alert.',
                          ),

                          SizedBox(
                            height: 13,
                          ),

                          _SosInformationRow(
                            icon: Icons
                                .share_location_outlined,
                            text:
                            'Your live location may be shared while the SOS remains active.',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // ==========================================
                    // 999 WARNING
                    // ==========================================

                    Container(
                      padding:
                      const EdgeInsets.all(
                        15,
                      ),
                      decoration: BoxDecoration(
                        borderRadius:
                        BorderRadius.circular(
                          16,
                        ),
                        color: Colors.amber
                            .withOpacity(
                          0.08,
                        ),
                        border: Border.all(
                          color: Colors.amber
                              .withOpacity(
                            0.35,
                          ),
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Icon(
                            Icons
                                .warning_amber_rounded,
                            size: 20,
                            color: Colors.amber,
                          ),

                          SizedBox(
                            width: 10,
                          ),

                          Expanded(
                            child: Text(
                              'SafeZone is a community safety platform. '
                                  'For life-threatening police, ambulance '
                                  'or fire emergencies, contact 999.',
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ==================================================
            // SEND SOS BUTTON
            // ==================================================

            Container(
              padding: const EdgeInsets.fromLTRB(
                20,
                12,
                20,
                18,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: colorScheme
                        .outlineVariant,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _selectedCategory.icon,
                        size: 18,
                        color: Colors.red,
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      Expanded(
                        child: Text(
                          _selectedCategory.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  SizedBox(
                    width:
                    double.infinity,
                    height: 56,
                    child:
                    FilledButton.icon(
                      style:
                      FilledButton.styleFrom(
                        backgroundColor:
                        Colors.red,
                        foregroundColor:
                        Colors.white,
                      ),
                      onPressed:
                      _isSending
                          ? null
                          : _sendSos,
                      icon: _isSending
                          ? const SizedBox(
                        width: 20,
                        height: 20,
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
                      label: Text(
                        _isSending
                            ? 'Sending SOS...'
                            : 'SEND SOS',
                        style:
                        const TextStyle(
                          fontWeight:
                          FontWeight
                              .bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  const Text(
                    'Tap only when emergency assistance is required.',
                    textAlign:
                    TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
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
}

// ============================================================
// SOS CATEGORY
// ============================================================

enum SosCategory {
  medical(
    code: 'medical',
    label: 'Medical Emergency',
    description:
    'Serious injury, fainting, breathing difficulty or another medical emergency.',
    icon:
    Icons.medical_services_outlined,
  ),

  crime(
    code: 'crime',
    label: 'Crime / Personal Threat',
    description:
    'Robbery, assault, stalking, harassment or a threat to your personal safety.',
    icon: Icons.shield_outlined,
  ),

  accident(
    code: 'accident',
    label: 'Accident',
    description:
    'Road accident, fall, collision or another unexpected accident.',
    icon: Icons.car_crash_outlined,
  ),

  fireHazard(
    code: 'fire_hazard',
    label: 'Fire / Hazard',
    description:
    'Fire, smoke, gas leak, electrical danger or another hazardous situation.',
    icon: Icons
        .local_fire_department_outlined,
  ),

  other(
    code: 'other',
    label: 'Other Emergency',
    description:
    'An urgent situation that does not match the categories above.',
    icon:
    Icons.warning_amber_rounded,
  ),

  unsure(
    code: 'unsure',
    label: 'Not Sure / Need Help',
    description:
    'Use this when you need help but are unsure which emergency category applies.',
    icon:
    Icons.help_outline_rounded,
  );

  final String code;

  final String label;

  final String description;

  final IconData icon;

  const SosCategory({
    required this.code,
    required this.label,
    required this.description,
    required this.icon,
  });
}

// ============================================================
// CATEGORY CARD
// ============================================================

class _SosCategoryCard
    extends StatelessWidget {
  final SosCategory category;

  final bool selected;

  final VoidCallback onTap;

  const _SosCategoryCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
        BorderRadius.circular(
          18,
        ),
        onTap: onTap,
        child: AnimatedContainer(
          duration:
          const Duration(
            milliseconds: 180,
          ),
          padding:
          const EdgeInsets.all(
            17,
          ),
          decoration: BoxDecoration(
            borderRadius:
            BorderRadius.circular(
              18,
            ),
            color: selected
                ? Colors.red
                .withOpacity(
              0.10,
            )
                : colorScheme
                .surfaceContainer,
            border: Border.all(
              width:
              selected ? 2 : 1,
              color: selected
                  ? Colors.red
                  : colorScheme
                  .outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration:
                BoxDecoration(
                  borderRadius:
                  BorderRadius.circular(
                    14,
                  ),
                  color: selected
                      ? Colors.red
                      .withOpacity(
                    0.15,
                  )
                      : colorScheme
                      .surfaceContainerHighest,
                ),
                child: Icon(
                  category.icon,
                  color: selected
                      ? Colors.red
                      : null,
                ),
              ),

              const SizedBox(
                width: 14,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      category.label,
                      style:
                      TextStyle(
                        fontSize: 15,
                        fontWeight:
                        FontWeight
                            .bold,
                        color: selected
                            ? Colors.red
                            : null,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      category
                          .description,
                      style:
                      const TextStyle(
                        fontSize: 10,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Icon(
                selected
                    ? Icons
                    .check_circle_rounded
                    : Icons
                    .radio_button_unchecked,
                color: selected
                    ? Colors.red
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
// SOS INFORMATION ROW
// ============================================================

class _SosInformationRow
    extends StatelessWidget {
  final IconData icon;

  final String text;

  const _SosInformationRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
        ),

        const SizedBox(
          width: 10,
        ),

        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}