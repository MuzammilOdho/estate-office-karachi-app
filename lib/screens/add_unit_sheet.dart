import 'package:flutter/material.dart';

import '../repositories/units_repository.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/validators.dart';

class AddUnitSheet extends StatefulWidget {
  final String? initialColony;
  final String? initialType;

  const AddUnitSheet({super.key, this.initialColony, this.initialType});

  @override
  State<AddUnitSheet> createState() => _AddUnitSheetState();
}

class _AddUnitSheetState extends State<AddUnitSheet> {
  final _formKey = GlobalKey<FormState>();
  final _unitsRepository = UnitsRepository();

  final _houseNoController = TextEditingController();
  final _blockController = TextEditingController();
  final _flatNoController = TextEditingController();
  final _newColonyController = TextEditingController();
  final _newTypeController = TextEditingController();

  bool _isLoadingDropdowns = true;
  List<String> _colonies = [];
  List<String> _types = [];

  String? _selectedColony;
  String? _selectedType;
  bool _addingNewColony = false;
  bool _addingNewType = false;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedColony = widget.initialColony;
    _selectedType = widget.initialType;
    _loadColonies();
  }

  @override
  void dispose() {
    _houseNoController.dispose();
    _blockController.dispose();
    _flatNoController.dispose();
    _newColonyController.dispose();
    _newTypeController.dispose();
    super.dispose();
  }

  Future<void> _loadColonies() async {
    setState(() => _isLoadingDropdowns = true);
    try {
      final colonies = await _unitsRepository.getColonies();

      // If we were opened with a pre-filled colony (the common case — the
      // FAB on the units-in-colony+type screen), load its types too before
      // showing anything. Otherwise the type dropdown could briefly render
      // with a selected value that isn't in its (still-empty) items list,
      // which Flutter treats as an error.
      var types = <String>[];
      if (widget.initialColony != null) {
        try {
          types = await _unitsRepository.getTypesForColony(widget.initialColony!);
        } catch (_) {
          // Fall through with an empty list — the field just defaults to
          // "add new type" instead, which is still usable.
        }
      }

      if (!mounted) return;
      setState(() {
        _colonies = colonies;
        _addingNewColony = colonies.isEmpty;
        _types = types;
        _addingNewType = types.isEmpty;
        _isLoadingDropdowns = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is AppException ? e.message : 'Something went wrong.';
        _isLoadingDropdowns = false;
      });
    }
  }

  Future<void> _loadTypesFor(String colony) async {
    try {
      final types = await _unitsRepository.getTypesForColony(colony);
      if (!mounted) return;
      setState(() {
        _types = types;
        _addingNewType = types.isEmpty;
      });
    } catch (_) {
      if (mounted) setState(() => _addingNewType = true);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final colony = _addingNewColony ? _newColonyController.text.trim() : (_selectedColony ?? '');
    final type = _addingNewType ? _newTypeController.text.trim() : (_selectedType ?? '');

    if (colony.isEmpty) {
      setState(() => _errorMessage = 'Enter or select a colony.');
      return;
    }
    if (type.isEmpty) {
      setState(() => _errorMessage = 'Enter or select a type.');
      return;
    }
    final houseNo = _houseNoController.text.trim();
    final block = _blockController.text.trim();
    final flatNo = _flatNoController.text.trim();
    if (houseNo.isEmpty && block.isEmpty && flatNo.isEmpty) {
      setState(() {
        _errorMessage = 'Enter at least a house no, or a block and flat no.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _unitsRepository.createUnit(
        houseNo: houseNo,
        block: block,
        flatNo: flatNo,
        colony: colony,
        type: type,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unit added.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is AppException ? e.message : 'Something went wrong.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('Add unit', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                if (_isLoadingDropdowns)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  )
                else ...[
                  _buildColonyField(),
                  const SizedBox(height: 12),
                  _buildTypeField(),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _blockController,
                        decoration: const InputDecoration(
                          labelText: 'Block (optional)',
                          hintText: 'C',
                        ),
                        style: AppTheme.numericData,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _flatNoController,
                        decoration: const InputDecoration(
                          labelText: 'Flat no (optional)',
                          hintText: '4',
                        ),
                        style: AppTheme.numericData,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _houseNoController,
                  decoration: const InputDecoration(
                    labelText: 'House no (optional)',
                    hintText: 'H-089',
                    helperText: 'Fill in House no, or Block + Flat no — whichever applies.',
                  ),
                  style: AppTheme.numericData,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(_errorMessage!, style: const TextStyle(color: AppColors.dueRed)),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text('Add unit'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColonyField() {
    if (_addingNewColony) {
      return TextFormField(
        controller: _newColonyController,
        decoration: InputDecoration(
          labelText: 'Colony',
          hintText: 'Gulshan Colony',
          suffixIcon: _colonies.isEmpty
              ? null
              : IconButton(
            icon: const Icon(Icons.list_outlined),
            tooltip: 'Choose existing colony',
            onPressed: () => setState(() => _addingNewColony = false),
          ),
        ),
        validator: (v) => Validators.required(v, label: 'Colony'),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedColony,
      decoration: const InputDecoration(labelText: 'Colony'),
      hint: const Text('Select colony'),
      items: [
        ..._colonies.map((c) => DropdownMenuItem(value: c, child: Text(c))),
        const DropdownMenuItem(value: '__new__', child: Text('+ Add new colony')),
      ],
      onChanged: (value) {
        if (value == '__new__') {
          setState(() {
            _addingNewColony = true;
            _selectedColony = null;
          });
          return;
        }
        setState(() {
          _selectedColony = value;
          _selectedType = null;
          _types = [];
        });
        if (value != null) _loadTypesFor(value);
      },
      validator: (v) => v == null ? 'Select a colony' : null,
    );
  }

  Widget _buildTypeField() {
    if (_addingNewType) {
      return TextFormField(
        controller: _newTypeController,
        decoration: InputDecoration(
          labelText: 'Type / category',
          hintText: 'Type A',
          suffixIcon: _types.isEmpty
              ? null
              : IconButton(
            icon: const Icon(Icons.list_outlined),
            tooltip: 'Choose existing type',
            onPressed: () => setState(() => _addingNewType = false),
          ),
        ),
        validator: (v) => Validators.required(v, label: 'Type'),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedType,
      decoration: const InputDecoration(labelText: 'Type / category'),
      hint: const Text('Select type'),
      items: [
        ..._types.map((t) => DropdownMenuItem(value: t, child: Text(t))),
        const DropdownMenuItem(value: '__new__', child: Text('+ Add new type')),
      ],
      onChanged: (value) {
        if (value == '__new__') {
          setState(() {
            _addingNewType = true;
            _selectedType = null;
          });
          return;
        }
        setState(() => _selectedType = value);
      },
      validator: (v) => v == null ? 'Select a type' : null,
    );
  }
}