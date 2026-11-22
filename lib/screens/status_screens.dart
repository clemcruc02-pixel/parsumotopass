import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

String statusTitle(AppStatus s) => switch (s) {
      AppStatus.submitted => 'Submitted',
      AppStatus.documentsReceived => 'Documents received',
      AppStatus.underReview => 'Under review',
      AppStatus.approved => 'Approved',
      AppStatus.readyForRelease => 'Ready for release',
    };

const _pendingText = {
  AppStatus.submitted: 'Application received',
  AppStatus.documentsReceived: 'Checked by the office',
  AppStatus.underReview: 'Now being evaluated',
  AppStatus.approved: 'Waiting for decision',
  AppStatus.readyForRelease: 'Pick up your sticker',
};

// ---------------------------------------------------------------------------
// 14. Tracking (shown inside the "My Application" tab)
// ---------------------------------------------------------------------------
class TrackingView extends StatelessWidget {
  const TrackingView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final current = state.status;
        return Column(
          children: [
            PageHeader(
              title: 'Tracking',
              subtitle: state.referenceNo,
              actions: [
                AlertBell(
                  hasDot: state.alerts.isNotEmpty,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AlertsScreen())),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                children: [
                  for (final s in AppStatus.values)
                    _TimelineStep(
                      title: statusTitle(s),
                      subtitle: _pendingText[s]!,
                      done: s.index < current.index ||
                          current == AppStatus.readyForRelease,
                      active: s == current &&
                          current != AppStatus.readyForRelease,
                      isLast: s == AppStatus.readyForRelease,
                      trailing: s == AppStatus.readyForRelease
                          ? GestureDetector(
                              onTap: current == AppStatus.readyForRelease
                                  ? () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const ReleaseScreen()))
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('View pickup details ›',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: current ==
                                                AppStatus.readyForRelease
                                            ? AppColors.greenDark
                                            : AppColors.inactive)),
                              ),
                            )
                          : null,
                    ),
                  const SizedBox(height: 24),
                  // Prototype-only control so the later screens can be previewed.
                  if (current != AppStatus.readyForRelease)
                    Center(
                      child: TextButton.icon(
                        onPressed: state.advanceStatus,
                        icon: const Icon(Icons.fast_forward,
                            size: 16, color: AppColors.muted),
                        label: const Text('Simulate next status (demo)',
                            style: TextStyle(color: AppColors.muted)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.active,
    required this.isLast,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final bool done;
  final bool active;
  final bool isLast;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    Widget dot;
    if (done) {
      dot = Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
            color: AppColors.green, shape: BoxShape.circle),
        child: const Icon(Icons.check, size: 14, color: AppColors.text),
      );
    } else if (active) {
      dot = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.green, width: 3),
        ),
      );
    } else {
      dot = Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
            color: AppColors.inactive, shape: BoxShape.circle),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                dot,
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: done ? AppColors.green : AppColors.inactive,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: done || active
                              ? AppColors.text
                              : AppColors.muted)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                  ?trailing,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 15. Alerts
// ---------------------------------------------------------------------------
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Scaffold(
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) => Column(
          children: [
            const PageHeader(
                title: 'Alerts', subtitle: 'Latest updates', showBack: true),
            Expanded(
              child: state.alerts.isEmpty
                  ? const Center(
                      child: Text('No updates yet',
                          style: TextStyle(color: AppColors.muted)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.alerts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final a = state.alerts[i];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: i == 0
                                ? AppColors.greenLight
                                : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.notifications,
                                  size: 20, color: AppColors.muted),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    Text(a.message,
                                        style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                              Text(a.time,
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.muted)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 16. Release
// ---------------------------------------------------------------------------
class ReleaseScreen extends StatelessWidget {
  const ReleaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ref = AppState.instance.referenceNo ?? '';
    const dashed = Divider(height: 1, color: AppColors.border);
    return Scaffold(
      body: Column(
        children: [
          const PageHeader(
              title: 'Release', subtitle: 'Sticker is ready', showBack: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color: AppColors.greenLight,
                        padding: const EdgeInsets.all(16),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ready for pickup',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800)),
                            Text('Canteen', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      dashed,
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Mon–Fri · 8:00 AM – 5:00 PM'),
                      ),
                      dashed,
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Bring',
                                style: TextStyle(color: AppColors.muted)),
                            const Text('Student ID',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            Text('Ref. $ref'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Show reference',
                  onPressed: () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: Colors.white,
                      title: const Text('Reference number',
                          textAlign: TextAlign.center),
                      content: Text(ref,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
