import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../providers/auth_provider.dart';
import '../repositories/units_repository.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../widgets/app_branding.dart';
import '../widgets/state_views.dart';
import 'add_unit_sheet.dart';
import 'audit_log_screen.dart';
import 'export_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'types_screen.dart';

/// Home screen: official masthead (logo + application name + tagline),
/// the estate-wide Search entry point in the app bar, and below it the
/// colony browse list (Colony → Category → Units drill-down unchanged).
///
/// The old always-visible global search field was removed — all searching
/// now goes through the structured, server-side Search screen opened
/// from the app bar's search icon.
class ColoniesScreen extends StatefulWidget {
  const ColoniesScreen({super.key});

  @override
  State<ColoniesScreen> createState() => _ColoniesScreenState();
}

enum _LoadState { loading, loaded, error }

class _ColoniesScreenState extends State<ColoniesScreen> {
  final _unitsRepository = UnitsRepository();

  _LoadState _coloniesState = _LoadState.loading;
  String? _errorMessage;
  List<String> _colonies = [];

  @override
  void initState() {
    super.initState();
    _loadColonies();
  }

  Future<void> _loadColonies() async {
    setState(() {
      _coloniesState = _LoadState.loading;
      _errorMessage = null;
    });
    try {
      final colonies = await _unitsRepository.getColonies();
      if (!mounted) return;
      setState(() {
        _colonies = colonies;
        _coloniesState = _LoadState.loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is AppException ? e.message : 'Something went wrong.';
        _coloniesState = _LoadState.error;
      });
    }
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        title: const Row(
          children: [
            AppLogo(size: 72),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                AppInfo.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
          ),
          IconButton(
            tooltip: 'Export report',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExportScreen()),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              } else if (value == 'audit_log') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AuditLogScreen()),
                );
              } else if (value == 'logout') {
                context.read<AuthProvider>().logout();
              }
            },
            itemBuilder: (context) => [
              if (context.read<AuthProvider>().isAdmin)
                const PopupMenuItem(value: 'audit_log', child: Text('Audit log')),
              const PopupMenuItem(value: 'settings', child: Text('Server settings')),
              const PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          // Keeps the content column at a readable width on tablets,
          // desktop and wide browser windows; phones are unaffected.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildColoniesList()),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: !context.watch<AuthProvider>().isAdmin
          ? null
          : FloatingActionButton(
              tooltip: 'Add unit',
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => const AddUnitSheet(),
              ).then((_) => _loadColonies()),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildColoniesList() {
    switch (_coloniesState) {
      case _LoadState.loading:
        return const LoadingView(message: 'Loading colonies…');
      case _LoadState.error:
        return ErrorRetryView(
          message: _errorMessage ?? 'Something went wrong.',
          onRetry: _loadColonies,
        );
      case _LoadState.loaded:
        if (_colonies.isEmpty) {
          return const EmptyStateView(
            icon: Icons.map_outlined,
            title: 'No areas yet',
            subtitle: 'Tap the + button to add the first unit.',
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadColonies,
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: _colonies.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Text(
                    'Areas',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                );
              }
              final colony = _colonies[index - 1];
              return Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                  ),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(
                    colony,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TypesScreen(colony: colony),
                    ),
                  ),
                ),
              );
            },
          ),
        );
    }
  }
}
