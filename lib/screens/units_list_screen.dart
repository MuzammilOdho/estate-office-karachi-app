// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
// import '../models/unit_list_item.dart';
// import '../providers/auth_provider.dart';
// import '../providers/units_list_provider.dart';
// import '../theme/app_theme.dart';
// import '../widgets/state_views.dart';
// import '../widgets/unit_card.dart';
// import 'add_unit_sheet.dart';
// import 'export_screen.dart';
// import 'settings_screen.dart';
// import 'unit_detail_sheet.dart';
//
// class UnitsListScreen extends StatelessWidget {
//   const UnitsListScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return ChangeNotifierProvider<UnitsListProvider>(
//       create: (_) => UnitsListProvider()..load(),
//       child: const _UnitsListView(),
//     );
//   }
// }
//
// class _UnitsListView extends StatelessWidget {
//   const _UnitsListView();
//
//   @override
//   Widget build(BuildContext context) {
//     final provider = context.watch<UnitsListProvider>();
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Estate Registry'),
//         actions: [
//           IconButton(
//             tooltip: 'Export monthly report',
//             icon: const Icon(Icons.ios_share_rounded),
//             onPressed: () => Navigator.of(context).push(
//               MaterialPageRoute(builder: (_) => const ExportScreen()),
//             ),
//           ),
//           PopupMenuButton<String>(
//             onSelected: (value) {
//               if (value == 'settings') {
//                 Navigator.of(context).push(
//                   MaterialPageRoute(builder: (_) => const SettingsScreen()),
//                 );
//               } else if (value == 'logout') {
//                 context.read<AuthProvider>().logout();
//               }
//             },
//             itemBuilder: (context) => [
//               const PopupMenuItem(
//                 value: 'settings',
//                 child: Text('Server settings'),
//               ),
//               const PopupMenuItem(
//                 value: 'logout',
//                 child: Text('Log out'),
//               ),
//             ],
//           ),
//         ],
//       ),
//       body: SafeArea(
//         child: Column(
//           children: [
//             Padding(
//               padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
//               child: TextField(
//                 onChanged: provider.setSearchQuery,
//                 decoration: const InputDecoration(
//                   hintText: 'Search by unit number or allottee name',
//                   prefixIcon: Icon(Icons.search),
//                 ),
//               ),
//             ),
//             Expanded(child: _buildBody(context, provider)),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         tooltip: 'Add unit',
//         onPressed: () => showModalBottomSheet(
//           context: context,
//           isScrollControlled: true,
//           useSafeArea: true,
//           builder: (_) => const AddUnitSheet(),
//         ).then((_) => provider.refresh()),
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
//
//   Widget _buildBody(BuildContext context, UnitsListProvider provider) {
//     switch (provider.state) {
//       case LoadState.loading:
//         return const LoadingView(message: 'Loading units…');
//       case LoadState.error:
//         return ErrorRetryView(
//           message: provider.errorMessage ?? 'Something went wrong.',
//           onRetry: provider.load,
//         );
//       case LoadState.loaded:
//         if (provider.isEmpty) {
//           return const EmptyStateView(
//             icon: Icons.home_work_outlined,
//             title: 'No units yet',
//             subtitle: 'Tap the + button to add the first unit.',
//           );
//         }
//         if (provider.hasNoSearchResults) {
//           return const EmptyStateView(
//             icon: Icons.search_off_rounded,
//             title: 'No matches',
//             subtitle: 'Try a different unit number or allottee name.',
//           );
//         }
//         final grouped = provider.groupedByArea;
//         return RefreshIndicator(
//           color: AppColors.brass,
//           onRefresh: provider.refresh,
//           child: ListView.builder(
//             padding: const EdgeInsets.only(bottom: 96, top: 4),
//             itemCount: grouped.length,
//             itemBuilder: (context, index) {
//               final entry = grouped[index];
//               return _AreaSection(
//                 area: entry.key,
//                 units: entry.value,
//                 onRefreshNeeded: provider.refresh,
//               );
//             },
//           ),
//         );
//     }
//   }
// }
//
// class _AreaSection extends StatelessWidget {
//   final String area;
//   final List<UnitListItem> units;
//   final VoidCallback onRefreshNeeded;
//
//   const _AreaSection({
//     required this.area,
//     required this.units,
//     required this.onRefreshNeeded,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
//           child: Text(
//             area,
//             style: Theme.of(context).textTheme.titleMedium,
//           ),
//         ),
//         ...units.map((item) => UnitCard(
//           item: item,
//           onTap: () => showModalBottomSheet(
//             context: context,
//             isScrollControlled: true,
//             useSafeArea: true,
//             builder: (_) => UnitDetailSheet(unitId: item.unit.id),
//           ).then((_) => onRefreshNeeded()),
//         )),
//       ],
//     );
//   }
// }