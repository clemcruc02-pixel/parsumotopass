import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';

enum _Stage {
  submitted('Submitted'),
  documentsReceived('Documents received'),
  underReview('Under review'),
  approved('Approved'),
  rejected('Rejected'),
  ready('Ready for pickup'),
  released('Released');

  const _Stage(this.label);
  final String label;
}

class _Request {
  _Request(this.reference, this.student, this.plate, this.stage);

  final String reference;
  final String student;
  final String plate;
  _Stage stage;
  String? rejectionReason;
  final verified = <String>{};
  final history = <String>[];
  static const documents = [
    'Student ID',
    'ID photocopy',
    'Registration (OR/CR)',
  ];
}

class OperationsPreview extends StatefulWidget {
  const OperationsPreview({super.key});

  @override
  State<OperationsPreview> createState() => _OperationsPreviewState();
}

class _OperationsPreviewState extends State<OperationsPreview> {
  final _requests = [
    _Request('DEMO-001', 'Sample Student A', 'DEMO 101', _Stage.submitted),
    _Request('DEMO-002', 'Sample Student B', 'DEMO 102', _Stage.underReview),
    _Request('DEMO-003', 'Sample Student C', 'DEMO 103', _Stage.ready),
  ];
  final _requirements = {
    'Student ID': true,
    'ID photocopy': true,
    'Registration (OR/CR)': true,
    'Motorcycle photo': false,
  };
  final _staff = {'Sample reviewer': true, 'Sample administrator': true};
  int _tab = 0;
  String _query = '';
  String _plate = '';
  String _recordsQuery = '';
  _Stage? _filter;
  String _pickupLocation = 'Campus service desk';
  String _pickupHours = 'Mon–Fri, 8:00 AM–5:00 PM';

  void _openStudentStatus(_Request request) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _StudentStatusPreview(
          request: request,
          location: _pickupLocation,
          hours: _pickupHours,
        ),
      ),
    );
  }

  Future<void> _editPickup() async {
    var location = _pickupLocation;
    var hours = _pickupHours;
    final form = GlobalKey<FormState>();
    final settings = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit pickup settings'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: location,
                decoration: const InputDecoration(labelText: 'Pickup location'),
                validator: requiredValidator,
                onChanged: (value) => location = value.trim(),
              ),
              TextFormField(
                initialValue: hours,
                decoration: const InputDecoration(labelText: 'Office hours'),
                validator: requiredValidator,
                onChanged: (value) => hours = value.trim(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, (location, hours));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (mounted && settings != null) {
      setState(() {
        _pickupLocation = settings.$1;
        _pickupHours = settings.$2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Operations preview')),
      body: Column(
        children: [
          const ListTile(
            tileColor: AppColors.greenLight,
            leading: Icon(Icons.science_outlined),
            title: Text('Sample data'),
            subtitle: Text('Changes reset when you leave this preview.'),
          ),
          Expanded(
            child: switch (_tab) {
              0 => _queue(),
              1 => _administration(),
              _ => _lookup(),
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (tab) => setState(() => _tab = tab),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            label: 'Review',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Admin',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            label: 'Lookup',
          ),
        ],
      ),
    );
  }

  Widget _queue() {
    final matches = _requests.where((request) {
      final searchable =
          '${request.reference} ${request.student} ${request.plate}';
      return searchable.toLowerCase().contains(_query) &&
          (_filter == null || request.stage == _filter);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Application queue',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        TextFormField(
          initialValue: _query,
          decoration: const InputDecoration(
            labelText: 'Search name, reference or plate',
          ),
          onChanged: (value) =>
              setState(() => _query = value.trim().toLowerCase()),
        ),
        DropdownButton<_Stage>(
          value: _filter,
          isExpanded: true,
          hint: const Text('All statuses'),
          items: [
            const DropdownMenuItem<_Stage>(child: Text('All statuses')),
            for (final stage in _Stage.values)
              DropdownMenuItem(value: stage, child: Text(stage.label)),
          ],
          onChanged: (value) => setState(() => _filter = value),
        ),
        if (matches.isEmpty)
          const ListTile(title: Text('No matching applications')),
        for (final request in matches)
          Card(
            child: ListTile(
              title: Text(request.reference),
              subtitle: Text('${request.student} · ${request.stage.label}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => _ReviewRequest(
                      request: request,
                      onStudentStatus: () => _openStudentStatus(request),
                    ),
                  ),
                );
                if (mounted) setState(() {});
              },
            ),
          ),
      ],
    );
  }

  Widget _administration() {
    final records = _requests.where(
      (request) => '${request.reference} ${request.plate}'
          .toLowerCase()
          .contains(_recordsQuery),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Staff access', style: Theme.of(context).textTheme.titleLarge),
        for (final entry in _staff.entries)
          SwitchListTile(
            title: Text(entry.key),
            subtitle: Text(
              entry.value ? 'Active in preview' : 'Inactive in preview',
            ),
            value: entry.value,
            onChanged: (value) => setState(() => _staff[entry.key] = value),
          ),
        const Divider(),
        Text(
          'Document requirements',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        for (final entry in _requirements.entries)
          SwitchListTile(
            title: Text(entry.key),
            subtitle: Text(
              entry.value
                  ? 'Required in configuration preview'
                  : 'Optional in configuration preview',
            ),
            value: entry.value,
            onChanged: (value) =>
                setState(() => _requirements[entry.key] = value),
          ),
        const Divider(),
        ListTile(
          title: const Text('Pickup settings'),
          subtitle: Text('$_pickupLocation\n$_pickupHours'),
          trailing: const Icon(Icons.edit_outlined),
          onTap: _editPickup,
        ),
        const Divider(),
        Text(
          'Application records',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        TextFormField(
          initialValue: _recordsQuery,
          decoration: const InputDecoration(
            labelText: 'Search reference or plate',
          ),
          onChanged: (value) =>
              setState(() => _recordsQuery = value.trim().toLowerCase()),
        ),
        if (records.isEmpty) const ListTile(title: Text('No matching records')),
        for (final request in records)
          ListTile(
            title: Text(request.reference),
            subtitle: Text(request.stage.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openStudentStatus(request),
          ),
      ],
    );
  }

  Widget _lookup() {
    final matches = _requests.where(
      (request) =>
          request.stage == _Stage.released &&
          request.plate.toUpperCase() == _plate,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Released sticker lookup',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        TextFormField(
          initialValue: _plate,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Exact plate number'),
          onChanged: (value) =>
              setState(() => _plate = value.trim().toUpperCase()),
        ),
        if (_plate.isNotEmpty && matches.isEmpty)
          const ListTile(title: Text('No released sticker found')),
        for (final request in matches)
          ListTile(
            leading: const Icon(Icons.verified_outlined),
            title: Text(request.plate),
            subtitle: Text('Released · ${request.reference}'),
          ),
      ],
    );
  }
}

class _ReviewRequest extends StatefulWidget {
  const _ReviewRequest({required this.request, required this.onStudentStatus});

  final _Request request;
  final VoidCallback onStudentStatus;

  @override
  State<_ReviewRequest> createState() => _ReviewRequestState();
}

class _ReviewRequestState extends State<_ReviewRequest> {
  _Request get request => widget.request;

  void _transition(_Stage next, {String? reason}) {
    setState(() {
      request.stage = next;
      request.rejectionReason = reason;
      request.history.insert(
        0,
        reason == null ? next.label : '${next.label} · $reason',
      );
    });
  }

  Future<void> _reject() async {
    var reason = '';
    final decision = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reject sample request'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Reason'),
            onChanged: (value) => setDialogState(() => reason = value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: reason.isEmpty
                  ? null
                  : () => Navigator.pop(context, reason),
              child: const Text('Reject'),
            ),
          ],
        ),
      ),
    );
    if (mounted && decision != null) {
      _transition(_Stage.rejected, reason: decision);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = request.stage;
    final next = switch (stage) {
      _Stage.submitted => _Stage.documentsReceived,
      _Stage.documentsReceived => _Stage.underReview,
      _Stage.underReview => _Stage.approved,
      _Stage.approved => _Stage.ready,
      _Stage.ready => _Stage.released,
      _ => null,
    };
    final action = switch (stage) {
      _Stage.submitted => 'Mark documents received',
      _Stage.documentsReceived => 'Start review',
      _Stage.underReview => 'Approve',
      _Stage.approved => 'Mark ready for pickup',
      _Stage.ready => 'Record pickup',
      _ => '',
    };

    return Scaffold(
      appBar: AppBar(title: Text(request.reference)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: Text(request.student),
            subtitle: Text('${request.plate} · ${stage.label}'),
          ),
          const Divider(),
          Text(
            'Document verification',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text('These sample requests have no attached files.'),
          for (final document in _Request.documents)
            CheckboxListTile(
              title: Text(document),
              value: request.verified.contains(document),
              onChanged: stage == _Stage.underReview
                  ? (value) => setState(() {
                      if (value == true) {
                        request.verified.add(document);
                      } else {
                        request.verified.remove(document);
                      }
                    })
                  : null,
            ),
          if (next != null)
            FilledButton(
              onPressed:
                  stage == _Stage.underReview &&
                      request.verified.length != _Request.documents.length
                  ? null
                  : () => _transition(next),
              child: Text(action),
            ),
          if (stage == _Stage.underReview)
            OutlinedButton(
              onPressed: _reject,
              child: const Text('Reject request'),
            ),
          TextButton(
            onPressed: widget.onStudentStatus,
            child: const Text('Preview student status'),
          ),
          const Divider(),
          Text('Status history', style: Theme.of(context).textTheme.titleLarge),
          if (request.history.isEmpty)
            const ListTile(title: Text('No changes in this preview')),
          for (final event in request.history) ListTile(title: Text(event)),
        ],
      ),
    );
  }
}

class _StudentStatusPreview extends StatelessWidget {
  const _StudentStatusPreview({
    required this.request,
    required this.location,
    required this.hours,
  });

  final _Request request;
  final String location;
  final String hours;

  @override
  Widget build(BuildContext context) {
    final stage = request.stage;
    return Scaffold(
      appBar: AppBar(title: const Text('Student status preview')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.assignment_outlined),
            title: Text(stage.label),
            subtitle: Text('Reference ${request.reference}'),
          ),
          if (request.rejectionReason case final reason?)
            ListTile(
              title: const Text('Decision reason'),
              subtitle: Text(reason),
            ),
          if (stage == _Stage.approved)
            const ListTile(
              title: Text('Pickup pending'),
              subtitle: Text('Check again when your sticker is ready.'),
            ),
          if (stage == _Stage.ready) ...[
            ListTile(
              title: const Text('Pickup location'),
              subtitle: Text(location),
            ),
            ListTile(title: const Text('Office hours'), subtitle: Text(hours)),
            const ListTile(
              title: Text('Bring your student ID and reference number'),
            ),
          ],
          if (request.history.isNotEmpty) ...[
            const Divider(),
            const ListTile(title: Text('Application updates')),
            for (final event in request.history) ListTile(title: Text(event)),
          ],
        ],
      ),
    );
  }
}
