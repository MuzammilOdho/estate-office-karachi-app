import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';

/// Lets staff attach one or more document photos — via the camera (one
/// at a time) or by picking several existing photos from the gallery in
/// one go. Exposes the current list through [DocumentPickerState.documents]
/// for the parent form to read on submit.
class DocumentPicker extends StatefulWidget {
  final ValueChanged<List<XFile>>? onChanged;

  const DocumentPicker({super.key, this.onChanged});

  @override
  State<DocumentPicker> createState() => DocumentPickerState();
}

class DocumentPickerState extends State<DocumentPicker> {
  final _picker = ImagePicker();
  final List<XFile> _documents = [];
  bool _isPicking = false;
  String? _errorMessage;

  List<XFile> get documents => List.unmodifiable(_documents);

  Future<void> _addFromCamera() async {
    setState(() {
      _isPicking = true;
      _errorMessage = null;
    });
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (photo != null) {
        setState(() => _documents.add(photo));
        widget.onChanged?.call(_documents);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = "Couldn't open the camera.");
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _addFromGallery() async {
    setState(() {
      _isPicking = true;
      _errorMessage = null;
    });
    try {
      final photos = await _picker.pickMultiImage(imageQuality: 85);
      if (photos.isNotEmpty) {
        setState(() => _documents.addAll(photos));
        widget.onChanged?.call(_documents);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = "Couldn't open the gallery.");
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _remove(int index) {
    setState(() => _documents.removeAt(index));
    widget.onChanged?.call(_documents);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isPicking ? null : _addFromCamera,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isPicking ? null : _addFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
        if (_isPicking) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(color: AppColors.brass),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(_errorMessage!, style: const TextStyle(color: AppColors.dueRed)),
        ],
        if (_documents.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _documents.length; i++)
                _DocumentThumb(file: _documents[i], onRemove: () => _remove(i)),
            ],
          ),
        ] else ...[
          const SizedBox(height: 8),
          const Text(
            'No documents attached yet.',
            style: TextStyle(color: AppColors.vacantGray, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

class _DocumentThumb extends StatelessWidget {
  final XFile file;
  final VoidCallback onRemove;

  const _DocumentThumb({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(file.path),
            width: 76,
            height: 76,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(12),
            child: const CircleAvatar(
              radius: 12,
              backgroundColor: AppColors.dueRed,
              child: Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}