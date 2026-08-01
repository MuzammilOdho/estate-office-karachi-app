import 'package:flutter/material.dart';

import '../services/pocketbase_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUrl();
  }

  Future<void> _loadCurrentUrl() async {
    final url = await SettingsService.instance.getServerUrl();
    if (!mounted) return;
    setState(() {
      _urlController.text = url;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final url = _urlController.text.trim();

    await SettingsService.instance.setServerUrl(url);
    await PocketBaseService.instance.updateBaseUrl(url);

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Server address saved.')),
    );
    Navigator.of(context).pop();
  }

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter the server address';
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Enter a full address, e.g. http://192.168.1.50:8090';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Server settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brass))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'This is the address of the PocketBase server running on '
                    'the office PC. Only change this if the office PC\'s '
                    'network address has changed.',
                style: TextStyle(color: AppColors.vacantGray),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                style: AppTheme.numericData,
                decoration: const InputDecoration(
                  labelText: 'PocketBase server URL',
                  hintText: 'http://192.168.1.50:8090',
                  prefixIcon: Icon(Icons.dns_outlined),
                ),
                validator: _validateUrl,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}