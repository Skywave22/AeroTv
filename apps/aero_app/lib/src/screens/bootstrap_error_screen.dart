import 'package:aero_ui/aero_ui.dart';
import 'package:flutter/material.dart';

/// Shown when the database could not be opened. Gives the user something
/// actionable instead of a black screen.
class BootstrapErrorScreen extends StatelessWidget {
  const BootstrapErrorScreen({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Aero TV could not start',
        message:
            'The local database could not be opened.\n\n$error\n\n'
            'If this keeps happening, clearing the app storage will reset '
            'Aero TV. Your add-ons can be restored from a backup.',
      ),
    );
  }
}
