import 'package:flutter/material.dart';

import '../../domain/entities/upload_result.dart';
import '../controllers/upload_progress_controller.dart';

/// Animated strip above the navigation bar showing each service's upload progress.
class UploadProgressStrip extends StatelessWidget {
  const UploadProgressStrip({super.key, required this.controller});

  final UploadProgressController controller;

  /// Builds one progress bar per service, or nothing when hidden.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final stages = controller.stages;
        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.bottomCenter,
          child: stages == null
              ? const SizedBox(width: double.infinity)
              : Container(
                  width: double.infinity,
                  color: const Color(0xFF0D101B),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final entry in stages.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 84,
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: switch (entry.value) {
                                    UploadStage.pending => 0,
                                    UploadStage.uploading => null,
                                    _ => 1,
                                  },
                                  minHeight: 4,
                                  backgroundColor: colors.outline.withValues(
                                    alpha: 0.4,
                                  ),
                                  color: switch (entry.value) {
                                    UploadStage.failed => colors.secondary,
                                    UploadStage.done => colors.tertiary,
                                    _ => colors.primary,
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 76,
                                child: Text(
                                  switch (entry.value) {
                                    UploadStage.pending => 'waiting',
                                    UploadStage.uploading => 'uploading',
                                    UploadStage.done => 'done',
                                    UploadStage.failed => 'failed',
                                  },
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
