import 'package:flutter/material.dart';
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppRadii;

import '../../core/app_theme.dart';

class ObservationSheet extends StatefulWidget {
  const ObservationSheet({super.key});

  @override
  State<ObservationSheet> createState() => _ObservationSheetState();
}

class _ObservationSheetState extends State<ObservationSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_controller.text.trim().isEmpty) {
      setState(() => _error = 'Escreva uma observação para salvar.');
      return;
    }
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: AppRadii.r99,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Adicionar observação',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Registre algo relevante sobre este atendimento. A gestão do petshop e o tutor também veem esta observação.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Observação',
                hintText: 'Ex.: apresentou sensibilidade na pata...',
                errorText: _error,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: _save, child: const Text('Salvar')),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
