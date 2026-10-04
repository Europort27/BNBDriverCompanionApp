/// Summary of a finished recording and its upload status.
class WardrivingSession {
  const WardrivingSession({
    required this.uniqueAccessPoints,
    required this.uniqueBluetoothIds,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.fileName,
    required this.uploaded,
    required this.uploadedToWdgwars,
    required this.uploadedToWardrift,
    this.filePath,
  });

  final int uniqueAccessPoints;
  final int uniqueBluetoothIds;
  final int durationSeconds;
  final double distanceMeters;
  final String fileName;
  final bool uploaded;
  final bool uploadedToWdgwars;
  final bool uploadedToWardrift;
  final String? filePath;

  /// Copy with new upload flags; `uploaded` is true only if both succeeded.
  WardrivingSession withUploadStatus({
    required bool uploadedToWdgwars,
    required bool uploadedToWardrift,
    String? filePath,
  }) {
    return WardrivingSession(
      uniqueAccessPoints: uniqueAccessPoints,
      uniqueBluetoothIds: uniqueBluetoothIds,
      durationSeconds: durationSeconds,
      distanceMeters: distanceMeters,
      fileName: fileName,
      uploaded: uploadedToWdgwars && uploadedToWardrift,
      uploadedToWdgwars: uploadedToWdgwars,
      uploadedToWardrift: uploadedToWardrift,
      filePath: filePath ?? this.filePath,
    );
  }

  /// Serialises the session for storage.
  Map<String, dynamic> toJson() => {
    'uniqueAccessPoints': uniqueAccessPoints,
    'uniqueBluetoothIds': uniqueBluetoothIds,
    'durationSeconds': durationSeconds,
    'distanceMeters': distanceMeters,
    'fileName': fileName,
    'uploaded': uploaded,
    'uploadedToWdgwars': uploadedToWdgwars,
    'uploadedToWardrift': uploadedToWardrift,
    'filePath': filePath,
  };

  /// Restores a session, tolerating entries saved by older app versions.
  factory WardrivingSession.fromJson(Map<String, dynamic> json) {
    return WardrivingSession(
      uniqueAccessPoints: json['uniqueAccessPoints'] as int,
      uniqueBluetoothIds: json['uniqueBluetoothIds'] as int? ?? 0,
      durationSeconds: json['durationSeconds'] as int,
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      fileName: json['fileName'] as String,
      uploaded: json['uploaded'] as bool,
      uploadedToWdgwars:
          json['uploadedToWdgwars'] as bool? ?? json['uploaded'] as bool,
      uploadedToWardrift:
          json['uploadedToWardrift'] as bool? ?? json['uploaded'] as bool,
      filePath: json['filePath'] as String?,
    );
  }
}
