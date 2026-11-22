import 'package:flutter_test/flutter_test.dart';
import 'package:parsu_motopass/data/app_state.dart';

void main() {
  setUp(AppState.instance.logout);

  test('Ownership changes retain common documents and drop owner data', () {
    final state = AppState.instance;
    final studentId = state.uploads.first;
    state.markUploaded(studentId, 'student-id.jpg');
    state.setOwnership(Ownership.notOwned);
    state.ownerName = 'Test Owner';
    state.markUploaded(state.uploads.last, 'consent.jpg');

    expect(state.uploads.first, same(studentId));
    expect(state.requiredUploadsReady, isFalse);
    state.setOwnership(Ownership.owned);
    expect(state.ownerName, isEmpty);
    expect(state.uploads.first.fileName, 'student-id.jpg');
    expect(state.uploads.any((slot) => slot.fileName == 'consent.jpg'), isFalse);
  });

  test('Only required documents gate upload readiness for each ownership', () {
    final state = AppState.instance;
    final optionalPhoto = state.uploads.singleWhere((slot) => !slot.required);
    expect(state.requiredUploadsReady, isFalse);

    for (final slot in state.uploads.where((slot) => slot.required)) {
      state.markUploaded(slot, 'test-document.jpg');
    }
    expect(state.requiredUploadsReady, isTrue);
    expect(optionalPhoto.uploaded, isFalse);

    state.setOwnership(Ownership.notOwned);
    expect(state.requiredUploadsReady, isFalse);

    final missingOwnerDocuments = state.uploads
        .where((slot) => slot.required && !slot.uploaded)
        .toList();
    expect(missingOwnerDocuments.map((slot) => slot.label), [
      "Owner's ID",
      'Consent letter',
    ]);
    state.markUploaded(missingOwnerDocuments.first, 'owner-id.jpg');
    expect(state.requiredUploadsReady, isFalse);
    state.markUploaded(missingOwnerDocuments.last, 'consent.jpg');
    expect(state.requiredUploadsReady, isTrue);
    expect(optionalPhoto.uploaded, isFalse);

    state.setOwnership(Ownership.owned);
    expect(state.requiredUploadsReady, isTrue);
  });

  test('Logout clears account, draft, documents and submission state', () {
    final state = AppState.instance;
    state.studentName = 'Test Student';
    state.fullName = 'Test Student';
    state.studentId = 'test-id';
    state.address = 'Test address';
    state.plateNo = 'TEST';
    state.setOwnership(Ownership.notOwned);
    state.ownerName = 'Test Owner';
    state.markUploaded(state.uploads.first, 'student-id.jpg');
    state.isDemo = true;
    state.submit();

    state.logout();

    expect(state.studentName, 'Student');
    expect(state.fullName, isEmpty);
    expect(state.studentId, isEmpty);
    expect(state.address, isEmpty);
    expect(state.plateNo, isEmpty);
    expect(state.ownerName, isEmpty);
    expect(state.ownership, Ownership.owned);
    expect(state.uploadedCount, 0);
    expect(state.hasActiveApplication, isFalse);
    expect(state.alerts, isEmpty);
  });
}
