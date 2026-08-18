import 'dart:async';

import 'package:flutter/material.dart';

import '../models/allottee_model.dart';
import '../repositories/allottees_repository.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/input_formatters.dart';
import '../utils/validators.dart';
import 'date_input_field.dart';

/// Lets staff either pick an allottee who's already on record (a transfer,
/// or re-allotting to a retired employee moving units) or enter a new
/// one. Exposes [resolveAllotteeId] for the parent form to call on
/// submit — it validates whichever mode is active and, for a new
/// allottee, creates the record and returns its id.
class AllotteePicker extends StatefulWidget {
  const AllotteePicker({super.key});

  @override
  State<AllotteePicker> createState() => AllotteePickerState();
}

class AllotteePickerState extends State<AllotteePicker> {
  final _allotteesRepository = AllotteesRepository();

  bool _existingMode = true;

  // "Existing allottee" mode
  final _searchController = TextEditingController();
  List<AllotteeModel> _searchResults = [];
  bool _isSearching = false;
  AllotteeModel? _selectedExisting;
  Timer? _debounce;
  /// Monotonic token — drops out-of-order search responses so a slow
  /// earlier query can't overwrite the results of a newer one.
  int _searchSeq = 0;

  // "New allottee" mode
  final _newFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cnicController = TextEditingController();
  final _designationController = TextEditingController();
  final _departmentController = TextEditingController();
  final _bsController = TextEditingController();
  final _personalNoController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime? _dob;

  String? _errorMessage;
  bool _isCreating = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _nameController.dispose();
    _cnicController.dispose();
    _designationController.dispose();
    _departmentController.dispose();
    _bsController.dispose();
    _personalNoController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    final seq = ++_searchSeq;
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await _allotteesRepository.search(query);
      if (!mounted || seq != _searchSeq) return;
      setState(() => _searchResults = results);
    } catch (_) {
      // Non-fatal — an empty result list is an acceptable fallback here.
    } finally {
      if (mounted && seq == _searchSeq) setState(() => _isSearching = false);
    }
  }

  /// Best-effort display name for whichever allottee [resolveAllotteeId]
  /// last resolved — only meaningful after a successful call, used to
  /// build a human-readable audit log summary.
  String get resolvedDisplayName {
    if (_existingMode) return _selectedExisting?.name ?? '';
    return _nameController.text.trim();
  }

  /// Returns the resolved allottee id, or null (with an inline error
  /// already shown) if the current input isn't valid yet.
  Future<String?> resolveAllotteeId() async {
    setState(() => _errorMessage = null);

    if (_existingMode) {
      if (_selectedExisting == null) {
        setState(() => _errorMessage = 'Search for and select an allottee.');
        return null;
      }
      return _selectedExisting!.id;
    }

    final formOk = _newFormKey.currentState?.validate() ?? false;
    if (!formOk) return null;

    setState(() => _isCreating = true);
    try {
      // Duplicate prevention: check CNIC, personal_no, phone.
      for (final entry in [
        MapEntry('cnic', _cnicController.text),
        MapEntry('personal_no', _personalNoController.text),
        MapEntry('phone', _phoneController.text),
      ]) {
        final conflict = await _allotteesRepository.findByExactField(
          field: entry.key,
          value: entry.value,
        );
        if (conflict != null) {
          final label = entry.key == 'cnic'
              ? 'CNIC'
              : entry.key == 'personal_no'
                  ? 'Personal No'
                  : 'Phone No';
          if (mounted) {
            setState(() {
              _errorMessage = '$label already exists (used by "$conflict").';
              _isCreating = false;
            });
          }
          return null;
        }
      }

      final created = await _allotteesRepository.createAllottee(
        name: _nameController.text,
        cnic: _cnicController.text,
        designation: _designationController.text,
        department: _departmentController.text,
        bs: _bsController.text,
        personalNo: _personalNoController.text,
        phone: _phoneController.text,
        dob: _dob,
      );
      return created.id;
    } catch (e) {
      if (!mounted) return null;
      setState(() {
        _errorMessage = e is AppException ? e.message : 'Something went wrong.';
      });
      return null;
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Allottee', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('Existing allottee'),
                selected: _existingMode,
                onSelected: (_) => setState(() {
                  _existingMode = true;
                  _errorMessage = null;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Text('New allottee'),
                selected: !_existingMode,
                onSelected: (_) => setState(() {
                  _existingMode = false;
                  _errorMessage = null;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_existingMode) _buildExistingSearch() else _buildNewForm(),
        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(_errorMessage!, style: const TextStyle(color: AppColors.dueRed)),
        ],
      ],
    );
  }

  Widget _buildExistingSearch() {
    if (_selectedExisting != null) {
      final a = _selectedExisting!;
      return Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          title: Text(a.name),
          subtitle: Text(a.cnic.isNotEmpty ? '${a.cnic} · ${a.serviceStatusLabel}' : a.serviceStatusLabel),
          trailing: TextButton(
            onPressed: () => setState(() => _selectedExisting = null),
            child: const Text('Change'),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search by name or CNIC',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _isSearching
                ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
                : null,
          ),
        ),
        if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final a = _searchResults[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    title: Text(a.name),
                    subtitle: Text(a.cnic.isNotEmpty ? '${a.cnic} · ${a.serviceStatusLabel}' : a.serviceStatusLabel),
                    onTap: () => setState(() {
                      _selectedExisting = a;
                      _searchResults = [];
                      _searchController.clear();
                    }),
                  ),
                );
              },
            ),
          ),
        ] else if (_searchController.text.trim().isNotEmpty && !_isSearching) ...[
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'No matches. Switch to "New allottee" if they\'re not on record yet.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNewForm() {
    return Form(
      key: _newFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (v) => Validators.required(v, label: 'Name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _cnicController,
            decoration: const InputDecoration(
              labelText: 'CNIC',
              hintText: '42101-1234567-1',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [CnicInputFormatter()],
            validator: Validators.cnic,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _personalNoController,
            decoration: const InputDecoration(labelText: 'Personal No (optional)'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Mobile No (optional)',
              hintText: '0300-1234567',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [PhoneInputFormatter()],
            validator: Validators.phone,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _designationController,
            decoration: const InputDecoration(labelText: 'Designation (optional)'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _departmentController,
            decoration: const InputDecoration(labelText: 'Department (optional)'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _bsController,
            decoration: const InputDecoration(labelText: 'BS / basic scale (optional)'),
          ),
          const SizedBox(height: 12),
          DateInputField(
            label: 'Date of birth',
            initialDate: _dob,
            firstDate: DateTime(1930),
            lastDate: DateTime.now(),
            required: false,
            onChanged: (d) => setState(() => _dob = d),
          ),
          if (_isCreating) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(color: AppColors.primary),
          ],
        ],
      ),
    );
  }
}