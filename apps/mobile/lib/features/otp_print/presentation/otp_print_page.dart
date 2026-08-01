import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/features/otp_print/application/otp_print_controller.dart';

class OtpPrintPage extends ConsumerStatefulWidget {
  const OtpPrintPage({super.key});

  @override
  ConsumerState<OtpPrintPage> createState() => _OtpPrintPageState();
}

class _OtpPrintPageState extends ConsumerState<OtpPrintPage> {
  final _label = TextEditingController();
  final List<File> _files = [];

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: true,
      withData: false,
    );
    if (result == null) return;
    setState(() {
      _files
        ..clear()
        ..addAll(
          result.paths.whereType<String>().map(File.new),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(otpPrintControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('OTP Print')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _label,
              decoration: const InputDecoration(
                labelText: 'Label (optional)',
                hintText: 'e.g. School certificates',
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: state.isLoading ? null : _pickFiles,
              icon: const Icon(Icons.upload_file),
              label: Text(
                _files.isEmpty
                    ? 'Select PDF documents'
                    : '${_files.length} PDF(s) selected',
              ),
            ),
            if (_files.isNotEmpty) ...[
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final file = _files[index];
                    final name = file.path.split(RegExp(r'[\\/]')).last;
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.picture_as_pdf),
                      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: state.isLoading
                            ? null
                            : () => setState(() => _files.removeAt(index)),
                      ),
                    );
                  },
                ),
              ),
            ] else
              const Expanded(
                child: Center(
                  child: Text(
                    'Upload one or more PDFs. Page limits are enforced by the server (default 10 pages).',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: state.isLoading || _files.isEmpty
                  ? null
                  : () => ref.read(otpPrintControllerProvider.notifier).createChallenge(
                        files: List<File>.from(_files),
                        documentLabel: _label.text.trim(),
                      ),
              child: Text(state.isLoading ? 'Uploading…' : 'Upload & get OTP'),
            ),
            const SizedBox(height: 16),
            state.when(
              data: (challenge) {
                if (challenge == null) {
                  return const SizedBox.shrink();
                }
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(challenge.documentLabel),
                        Text('${challenge.pageCount} page(s) · ${challenge.documents.length} file(s)'),
                        const SizedBox(height: 8),
                        Text(
                          challenge.code,
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        Text('Expires: ${challenge.expiresAt}'),
                        const SizedBox(height: 4),
                        const Text('Also sent via SMS. Enter this OTP on the kiosk.'),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(
                error.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
