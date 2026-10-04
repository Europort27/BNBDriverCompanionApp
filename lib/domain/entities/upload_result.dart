/// Progress of one upload destination.
enum UploadStage { pending, uploading, done, failed }

/// Outcome of an upload attempt for each destination.
class UploadResult {
  const UploadResult({
    required this.uploadedToWdgwars,
    required this.uploadedToWardrift,
    this.wdgwarsError,
    this.wardriftError,
  });

  // Nothing was attempted (debug mode, or no API keys configured).
  static const none = UploadResult(
    uploadedToWdgwars: false,
    uploadedToWardrift: false,
  );

  final bool uploadedToWdgwars;
  final bool uploadedToWardrift;
  final String? wdgwarsError;
  final String? wardriftError;
}
