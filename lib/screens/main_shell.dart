import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'apply_screens.dart';
import 'auth_screens.dart';
import 'status_screens.dart';

/// Root after login: Home and My Application tabs.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeTab(onTrack: () => setState(() => _tab = 1)),
          const MyApplicationTab(),
        ],
      ),
      bottomNavigationBar: AppTabBar(
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    Widget tab(int i, String label) {
      final selected = i == index;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(i),
          child: Container(
            height: 58 + bottom,
            padding: EdgeInsets.only(bottom: bottom),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: selected ? AppColors.greenLight : Colors.transparent,
                  width: 4,
                ),
              ),
            ),
            child: Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
          ),
        ),
      );
    }

    return Material(
      color: AppColors.header,
      child: Row(children: [tab(0, 'Home'), tab(1, 'My Application')]),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.onTrack});
  final VoidCallback onTrack;

  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
                leading: Icon(Icons.person_outline), title: Text('Profile')),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log out'),
              onTap: () {
                AppState.instance.logout();
                Navigator.of(ctx).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => Column(
        children: [
          PageHeader(
            title: 'Hi, ${state.studentName}',
            subtitle: 'Welcome to ParSU Motopass',
            actions: [
              AlertBell(
                hasDot: state.alerts.isNotEmpty,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AlertsScreen())),
              ),
              IconButton(
                onPressed: () => _openSettings(context),
                icon: const Icon(Icons.settings, color: Colors.white),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StatusCard(onTrack: onTrack),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ShortcutCard(
                        title: 'Requirements',
                        subtitle: 'What to prepare',
                        icon: Icons.checklist,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  const RequirementsScreen(viewOnly: true)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ShortcutCard(
                        title: 'Track',
                        subtitle: 'Check status',
                        icon: Icons.timeline,
                        onTap: onTrack,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.onTrack});
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final active = state.hasActiveApplication;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Motor Sticker',
              style: TextStyle(color: Colors.white, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            active ? statusTitle(state.status) : 'No active application',
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          if (active)
            Text('Ref. ${state.referenceNo}',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
            child: PrimaryButton(
              label: active ? 'Track application' : 'Apply now',
              onPressed: active
                  ? onTrack
                  : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const RequirementsScreen())),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.lightCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppColors.muted),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              Text(subtitle, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class MyApplicationTab extends StatelessWidget {
  const MyApplicationTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        if (state.hasActiveApplication) return const TrackingView();
        return Column(
          children: [
            const PageHeader(
                title: 'My Application', subtitle: 'Motor sticker request'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.two_wheeler,
                        size: 64, color: AppColors.inactive),
                    const SizedBox(height: 12),
                    const Text('No active application',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text(
                      'Apply for a motor sticker to start tracking your request here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Apply now',
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const RequirementsScreen())),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
