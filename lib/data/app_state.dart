import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'student_api.dart';

enum Ownership { owned, notOwned }

enum AppStatus {
  submitted, documentsReceived, underReview, approved, readyForRelease,
  rejected, released, needsCorrection,
}

class UploadSlot {
  UploadSlot(this.label, {this.hint = '', this.required = true});
  final String label;
  final String hint;
  final bool required;
  String? fileName;
  Uint8List? bytes;
  bool get uploaded => fileName != null;
}

class AlertItem {
  AlertItem(this.title, this.message, this.time);
  final String title;
  final String message;
  final String time;
}

/// Holds the current student session and the draft being edited.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();
  static const apiUrl = String.fromEnvironment('MOTOPASS_API_URL');
  StudentApi? _api;
  bool get hasStudentSession => _api != null && !isStaff;
  bool isStaff = false;
  Set<String> staffPermissions = {};
  bool isDemo = false;
  bool submitting = false;
  bool _photoRequired = false;
  bool _correctionPhotoRequired = false;

  Future<void> signIn(String login, String password, {required bool demo}) async {
    if (demo) {
      isDemo = true;
      return;
    }
    final api = StudentApi(apiUrl);
    final data = await api.request('POST', 'sessions', body: {
      'login': login,
      'password': password,
    });
    final student = data['student'] as Map<String, dynamic>;
    fullName = student['name'] as String;
    studentName = fullName.split(' ').first;
    studentId = student['id'] as String;
    api.token = data['token'] as String;
    _api = api;
    isDemo = false;
    isStaff = data['staff'] == true;
    staffPermissions = (data['permissions'] as List<dynamic>? ?? [])
        .cast<String>().toSet();
    _photoRequired = data['photoRequired'] == true;
    uploads = _buildUploads();
    if (data['application'] case final Map<String, dynamic> application) {
      _recordSubmission(application);
    }
  }

  Future<void> signOut() async {
    final api = _api;
    logout();
    if (api == null) return;
    try {
      await api.request('DELETE', 'sessions/current');
    } on StudentApiException catch (error) {
      if (error.status != 401) rethrow;
    } finally {
      api.token = null;
    }
  }

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
  String? _newApplicationKey;
  AppStatus status = AppStatus.submitted;
  Map<String, dynamic>? pickup;
  int _revision = -1;
  Future<void>? _refresh;
  bool get refreshing => _refresh != null;
  String? refreshError;
  final List<AlertItem> alerts = [];

  bool get hasActiveApplication => referenceNo != null;
  bool get canCorrectApplication => status == AppStatus.needsCorrection;
  bool get canStartAnotherApplication =>
      !isDemo && (status == AppStatus.rejected || status == AppStatus.released);

  void beginAnotherApplication() {
    if (!canStartAnotherApplication || _newApplicationKey != null) return;
    final random = Random.secure();
    _newApplicationKey = List.generate(
      16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    ownership = Ownership.owned;
    plateNo = '';
    color = '';
    brandModel = '';
    orCrNo = '';
    ownerName = '';
    uploads = _buildUploads();
  }
  bool get notOwned => ownership == Ownership.notOwned;
  bool get requiresMotorcyclePhoto =>
      canCorrectApplication ? _correctionPhotoRequired : _photoRequired;
  int get uploadedCount => uploads.where((u) => u.uploaded).length;
  bool get requiredUploadsReady =>
      uploads.every((slot) => !slot.required || slot.uploaded);

  void updateDraft() => notifyListeners();

  List<UploadSlot> _buildUploads() => [
        UploadSlot('Student ID', hint: 'Front side, clear photo'),
        if (isDemo || !hasStudentSession) UploadSlot('ID photocopy'),
        UploadSlot('Registration (OR/CR)'),
        UploadSlot(
          'Motorcycle photo',
          required: requiresMotorcyclePhoto,
        ),
        if (notOwned) ...[
          UploadSlot("Owner's ID"),
          UploadSlot('Consent letter'),
        ],
      ];

  void setOwnership(Ownership o) {
    if (o == ownership) return;
    final previous = {for (final slot in uploads) slot.label: slot};
    ownership = o;
    if (!notOwned) ownerName = '';
    uploads = _buildUploads()
        .map((slot) => previous[slot.label] ?? slot)
        .toList();
    notifyListeners();
  }

  void markUploaded(UploadSlot slot, String name, {Uint8List? bytes}) {
    if (!uploads.contains(slot) || submitting ||
        (hasActiveApplication && !canCorrectApplication && _newApplicationKey == null)) {
      return;
    }
    slot.fileName = name;
    slot.bytes = bytes;
    notifyListeners();
  }

  void removeUpload(UploadSlot slot) {
    slot.fileName = null;
    slot.bytes = null;
    notifyListeners();
  }

  Future<void> submit() async {
    if (submitting ||
        (hasActiveApplication && !canCorrectApplication && _newApplicationKey == null)) {
      return;
    }
    if (isDemo) {
      _submitDemo();
      return;
    }
    final api = _api;
    if (api == null) {
      throw const StudentApiException('Sign in to submit your application.');
    }
    if (!requiredUploadsReady || uploads.any((u) => u.uploaded && u.bytes == null)) {
      throw const StudentApiException('Select all required documents before submitting.');
    }
    submitting = true;
    notifyListeners();
    try {
      final response = await api.request('POST', 'application', body: {
        if (_newApplicationKey case final key?) ...{
          'newApplication': true,
          'submissionKey': key,
        },
        if (canCorrectApplication) 'correctionRevision': _revision,
        'details': {
          'ownership': ownership.name,
          'course': course,
          'yearSection': yearSection,
          'contact': contact,
          if (address.isNotEmpty) 'address': address,
          'plateNo': plateNo,
          'color': color,
          'brandModel': brandModel,
          'orCrNo': orCrNo,
          if (notOwned) 'ownerName': ownerName,
        },
        'documents': {
          for (final slot in uploads.where((u) => u.uploaded))
            slot.label: {
              'filename': slot.fileName,
              'content': base64Encode(slot.bytes!),
            },
        },
      });
      if (identical(_api, api)) {
        _recordSubmission(response['application'] as Map<String, dynamic>);
        _newApplicationKey = null;
      }
    } finally {
      if (identical(_api, api)) {
        submitting = false;
        notifyListeners();
      }
    }
  }

  void _recordSubmission(Map<String, dynamic> application) {
    final revision = application['revision'] as int;
    if (application['reference'] == referenceNo && revision <= _revision) return;
    _revision = revision;
    referenceNo = application['reference'] as String;
    status = AppStatus.values.byName(application['status'] as String);
    pickup = application['pickup'] as Map<String, dynamic>?;
    if (canCorrectApplication) {
      final details = application['details'] as Map<String, dynamic>;
      _correctionPhotoRequired =
          (application['requiredDocuments'] as List).contains('Motorcycle photo');
      ownership = Ownership.values.byName(details['ownership'] as String);
      course = details['course'] as String;
      yearSection = details['yearSection'] as String;
      contact = details['contact'] as String;
      plateNo = details['plateNo'] as String;
      color = details['color'] as String;
      brandModel = details['brandModel'] as String;
      orCrNo = details['orCrNo'] as String;
      ownerName = details['ownerName'] as String? ?? '';
      uploads = _buildUploads();
    }
    for (final slot in uploads) {
      slot.bytes = null;
      slot.fileName = null;
    }
    alerts.clear();
    for (final event in (application['history'] as List<dynamic>? ?? [])) {
      final raw = event as Map<String, dynamic>;
      final eventStatus = AppStatus.values.byName(raw['status'] as String);
      alerts.add(AlertItem(
        eventStatus.name.replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m[0]!.toLowerCase()}'),
        raw['reason'] as String? ?? switch (eventStatus) {
          AppStatus.submitted => 'We received application $referenceNo.',
          AppStatus.documentsReceived => 'The permit office received your documents.',
          AppStatus.underReview => 'The permit office is reviewing your application.',
          AppStatus.approved => 'Your sticker application was approved.',
          AppStatus.readyForRelease => 'Your sticker is ready for pickup. Bring your student ID and reference.',
          AppStatus.released => 'The permit office recorded your sticker pickup.',
          AppStatus.rejected => 'The permit office rejected your application.',
          AppStatus.needsCorrection => 'Update the application and submit it again.',
        },
        raw['recorded_at'] as String,
      ));
    }
  }

  Future<void> refreshApplication() async {
    final api = _api;
    if (api == null || isStaff) return;
    final pending = _refresh;
    if (pending != null) return pending;
    final request = _fetchApplication(api);
    _refresh = request;
    refreshError = null;
    notifyListeners();
    try {
      await request;
    } finally {
      if (identical(_refresh, request)) {
        _refresh = null;
        notifyListeners();
      }
    }
  }

  Future<void> _fetchApplication(StudentApi api) async {
    final startedWith = referenceNo;
    try {
      final response = await api.request('GET', 'application');
      if (!identical(_api, api)) return;
      if (response['application'] case final Map<String, dynamic> application) {
        if (referenceNo != startedWith && application['reference'] != referenceNo) return;
        _recordSubmission(application);
      }
    } on StudentApiException catch (error) {
      if (identical(_api, api)) refreshError = error.message;
    }
  }

  Future<List<Map<String, dynamic>>> applicationHistory() async {
    final api = _api;
    if (api == null || isStaff) {
      throw const StudentApiException('Sign in with a student account.');
    }
    final data = await api.request('GET', 'applications');
    return (data['applications'] as List).cast<Map<String, dynamic>>();
  }

  Future<Uint8List> staffDocument(String reference, String slot) async {
    final api = _api;
    if (api == null || !isStaff) {
      throw const StudentApiException('Sign in with a staff account.');
    }
    return api.document('staff/applications/$reference/document', slot);
  }

  Future<Map<String, dynamic>> staffRequest(
    String method, String path, {
      Map<String, dynamic>? body,
    }
  ) {
    final api = _api;
    if (api == null || !isStaff) {
      throw const StudentApiException('Sign in with a staff account.');
    }
    return api.request(method, 'staff/$path', body: body);
  }

  void _submitDemo() {
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
    if (!isDemo || status == AppStatus.readyForRelease) return;
    status = AppStatus.values[status.index + 1];
    if (status == AppStatus.approved) {
      alerts.insert(0, AlertItem('Application approved', 'Your motor sticker was approved.', 'Just now'));
    } else if (status == AppStatus.readyForRelease) {
      alerts.insert(0, AlertItem('Ready for release', 'Your sticker is ready for pickup.', 'Just now'));
    }
    notifyListeners();
  }

  void logout() {
    _api = null;
    isStaff = false;
    staffPermissions = {};
    _photoRequired = false;
    _correctionPhotoRequired = false;
    isDemo = false;
    submitting = false;
    studentName = 'Student';
    ownership = Ownership.owned;
    fullName = '';
    studentId = '';
    course = '';
    yearSection = '';
    contact = '';
    address = '';
    plateNo = '';
    color = '';
    brandModel = '';
    orCrNo = '';
    ownerName = '';
    referenceNo = null;
    _newApplicationKey = null;
    status = AppStatus.submitted;
    pickup = null;
    _revision = -1;
    _refresh = null;
    refreshError = null;
    alerts.clear();
    uploads = _buildUploads();
    notifyListeners();
  }
}
