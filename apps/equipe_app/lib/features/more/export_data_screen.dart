import 'dart:typed_data';

import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppContentCard, AppScreenTips, AppTextStyles, AppTourTarget;
import 'package:flutter/material.dart';

import '../../core/file_saver.dart';
import '../../core/image_sharer.dart';
import '../../core/screen_tips.dart';
import '../../core/widgets.dart';
import '../../state/app_scope.dart';
import 'billing_models.dart';

/// Export of a petshop's data (E2): customers, pets and appointments as CSV
/// files, for the principal manager to keep. It is a copy: nothing is changed
/// or deleted on the platform, and each export is recorded by the server.
class ExportDataScreen extends StatefulWidget {
  const ExportDataScreen({
    super.key,
    required this.tenantId,
    required this.tenantName,
    this.saver = const PlatformDocumentSaver(),
    this.sharer = const PlatformFilesSharer(),
    this.canSave,
    this.canShare,
  });
  final String tenantId;
  final String tenantName;
  final DocumentSaver saver;
  final FilesSharer sharer;

  /// Overrides for the tests; by default, the device decides.
  final bool? canSave;
  final bool? canShare;

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  TenantExport? _export;
  String? _error;
  String? _message;
  bool _loading = false;

  bool get _canSave => widget.canSave ?? imageSaveAvailable;
  bool get _canShare => widget.canShare ?? imageShareAvailable;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });
    try {
      final result = await AppScope.of(
        context,
      ).exportTenantData(widget.tenantId);
      if (mounted) setState(() => _export = result);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().contains('demais')
              ? 'Há registros demais para exportar de uma vez. Fale com o Suporte da plataforma.'
              : 'Não foi possível exportar os dados. Confira a conexão e tente de novo.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(ExportFile file) async {
    try {
      final outcome = await widget.saver.saveDocument(
        file.name,
        Uint8List.fromList(file.bytes),
        'text/csv',
      );
      if (mounted) {
        setState(
          () => _message = outcome == SaveOutcome.saved
              ? '${file.name} salvo.'
              : null,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'Não foi possível salvar.');
    }
  }

  Future<void> _share(TenantExport export) async {
    try {
      await widget.sharer.shareFiles([
        for (final file in export.files)
          (file.name, Uint8List.fromList(file.bytes), 'text/csv'),
      ], title: 'Dados de ${export.tenantName}');
    } catch (_) {
      if (mounted) setState(() => _message = 'Não foi possível compartilhar.');
    }
  }

  static String _label(String name) => switch (name) {
    'clientes.csv' => 'Clientes',
    'pets.csv' => 'Pets',
    'agendamentos.csv' => 'Agendamentos',
    _ => name,
  };

  int _count(TenantExport export, String name) => switch (name) {
    'clientes.csv' => export.customers,
    'pets.csv' => export.pets,
    'agendamentos.csv' => export.appointments,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    final export = _export;
    return AppScreenTips(
      screen: TipScreens.dataExport,
      tips: TeamTips.dataExport,
      child: Scaffold(
        appBar: AppBar(title: const Text('Exportar dados')),
        body: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.tenantName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Uma cópia dos clientes, pets e agendamentos deste petshop, em planilhas. Nada é apagado nem alterado na plataforma, e cada exportação fica registrada.',
                style: AppTextStyles.captionMuted,
              ),
              const SizedBox(height: 18),
              AppTourTarget(
                id: TipTargets.exportFiles,
                child: export == null
                    ? FilledButton.icon(
                        onPressed: _loading ? null : _generate,
                        icon: _loading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download_rounded),
                        label: const Text('Gerar arquivos'),
                      )
                    : AppContentCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Column(
                          children: [
                            for (final file in export.files)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.table_chart_outlined),
                                title: Text(_label(file.name)),
                                subtitle: Text(
                                  '${file.name} · ${_count(export, file.name)} registros',
                                ),
                                trailing: _canSave
                                    ? TextButton(
                                        onPressed: () => _save(file),
                                        child: const Text('Salvar'),
                                      )
                                    : null,
                              ),
                          ],
                        ),
                      ),
              ),
              if (export != null && _canShare) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _share(export),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Compartilhar os 3 arquivos'),
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(_message!, textAlign: TextAlign.center),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: AppTextStyles.danger),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
