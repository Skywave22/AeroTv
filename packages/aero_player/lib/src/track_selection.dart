import 'package:flutter/material.dart';

import 'player_controller.dart';

/// Bottom sheet for choosing audio / subtitle tracks and playback speed.
class TrackSelectionSheet extends StatelessWidget {
  const TrackSelectionSheet({
    required this.controller,
    this.externalSubtitles = const [],
    this.onAddExternal,
    super.key,
  });

  final AeroPlayerController controller;
  final List<({String id, String label, String lang})> externalSubtitles;
  final void Function(String id)? onAddExternal;

  static Future<void> show(
    BuildContext context, {
    required AeroPlayerController controller,
    List<({String id, String label, String lang})> externalSubtitles = const [],
    void Function(String id)? onAddExternal,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF0F1116),
        builder: (_) => TrackSelectionSheet(
          controller: controller,
          externalSubtitles: externalSubtitles,
          onAddExternal: onAddExternal,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final snap = controller.snapshot;
        final audio = snap.tracks.where((t) => t.kind == TrackKind.audio).toList();
        final subs = snap.tracks.where((t) => t.kind == TrackKind.subtitle).toList();
        final theme = Theme.of(context);

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.75,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Playback', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 18),

                  _label(context, 'Speed'),
                  Wrap(
                    spacing: 8,
                    children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((r) {
                      final selected = (snap.rate - r).abs() < 0.01;
                      return ChoiceChip(
                        label: Text('${r}x'),
                        selected: selected,
                        onSelected: (_) => controller.setRate(r),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  if (audio.isNotEmpty) ...[
                    _label(context, 'Audio'),
                    ...audio.map((t) => RadioListTile<String>(
                          value: t.id,
                          // ignore: deprecated_member_use
                          groupValue: snap.track.audioId,
                          // ignore: deprecated_member_use
                          onChanged: (v) {
                            if (v != null) controller.selectAudio(v);
                          },
                          title: Text(t.label),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        )),
                    const SizedBox(height: 12),
                  ],

                  _label(context, 'Subtitles'),
                  RadioListTile<String?>(
                    value: null,
                    // ignore: deprecated_member_use
                    groupValue: snap.track.subtitleId,
                    // ignore: deprecated_member_use
                    onChanged: (_) => controller.selectSubtitle(null),
                    title: const Text('Off'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  ...subs.map((t) => RadioListTile<String>(
                        value: t.id,
                        // ignore: deprecated_member_use
                        groupValue: snap.track.subtitleId,
                        // ignore: deprecated_member_use
                        onChanged: (v) => controller.selectSubtitle(v),
                        title: Text(t.label),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      )),
                  if (externalSubtitles.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _label(context, 'From add-ons'),
                    ...externalSubtitles.map((s) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.closed_caption_outlined, size: 20),
                          title: Text(s.label),
                          trailing: const Icon(Icons.add_rounded, size: 18),
                          onTap: () {
                            onAddExternal?.call(s.id);
                            Navigator.of(context).maybePop();
                          },
                        )),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white54,
                letterSpacing: 1,
              ),
        ),
      );
}
