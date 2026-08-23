import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRecoveryHandler {
  StreamSubscription<AuthState>? _subscription;

  void start({
    required VoidCallback onPasswordRecovery,
  }) {
    _subscription?.cancel();

    _subscription =
        Supabase.instance.client.auth.onAuthStateChange.listen(
              (data) {
            debugPrint('AUTH EVENT = ${data.event}');

            if (data.event == AuthChangeEvent.passwordRecovery) {
              debugPrint('PASSWORD RECOVERY EVENT RECEIVED');

              onPasswordRecovery();
            }
          },
          onError: (error, stackTrace) {
            debugPrint(
              'AUTH RECOVERY ERROR = $error',
            );
          },
        );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}