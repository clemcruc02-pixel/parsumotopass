import 'package:flutter/foundation.dart';

enum Ownership { owned, notOwned }

enum AppStatus { submitted, documentsReceived, underReview, approved, readyForRelease }

class UploadSlot {
  UploadSlot(this.label, {this.hint = ''});
  final String label;
  final String hint;
  String? fileName;
  bool get uploaded => fileName != null;
}

class AlertItem {
  AlertItem(this.title, this.message, this.time);
  final String title;
  final String message;
  final String time;
}

/// In-memory app state for the UI prototype (no backend yet).
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  // Account
  String studentName = 'Student';

  // Application draft
  Ownership ownership = Ownership.owned;

  String fullName = '';
  String studentId = '';
  String course = '';
  String yearSection = '';
  String contact = '';
  String address = '';

  String plateNo = '';
  String color = '';
  String brandModel = '';
  String orCrNo = '';
  String ownerName = '';

  late List<UploadSlot> uploads = _buildUploads();

  // Submitted application
  String? referenceNo;
  AppStatus status = AppStatus.submitted;
  final List<AlertItem> alerts = [];

  bool get hasActiveApplication => referenceNo != null;
  bool get notOwned => ownership == Ownership.notOwned;
  int get uploadedCount => uploads.where((u) => u.uploaded).length;

  List<UploadSlot> _buildUploads() => [
        UploadSlot('Student ID', hint: 'Front side, clear photo'),
        UploadSlot('ID photocopy'),
        UploadSlot('Registration (OR/CR)'),
        UploadSlot('Motorcycle photo', hint: 'If required'),
        if (notOwned) ...[
          UploadSlot("Owner's ID"),
          UploadSlot('Consent letter'),
        ],
      ];

  void setOwnership(Ownership o) {
    ownership = o;
    uploads = _buildUploads();
    notifyListeners();
  }

  void markUploaded(UploadSlot slot, String name) {
    slot.fileName = name;
    notifyListeners();
  }

  void removeUpload(UploadSlot slot) {
    slot.fileName = null;
    notifyListeners();
  }

  void submit() {
    referenceNo = 'MS-2026-00123';
    status = AppStatus.underReview;
    alerts
      ..clear()
      ..addAll([
        AlertItem('Under review', 'Your application is now being evaluated.', 'Just now'),
        AlertItem('Submission received', 'We received your application $referenceNo.', 'Just now'),
      ]);
    notifyListeners();
  }

  /// Prototype helper: move the status forward to preview later screens.
  void advanceStatus() {
    if (status == AppStatus.readyForRelease) return;
    status = AppStatus.values[status.index + 1];
    if (status == AppStatus.approved) {
      alerts.insert(0, AlertItem('Application approved', 'Your motor sticker was approved.', 'Just now'));
    } else if (status == AppStatus.readyForRelease) {
      alerts.insert(0, AlertItem('Ready for release', 'Your sticker is ready for pickup.', 'Just now'));
    }
    notifyListeners();
  }

  void logout() {
    referenceNo = null;
    status = AppStatus.submitted;
    alerts.clear();
    uploads = _buildUploads();
    notifyListeners();
  }
}
