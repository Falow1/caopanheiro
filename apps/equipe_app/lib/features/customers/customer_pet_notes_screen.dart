import 'package:caopanheiro_contracts/caopanheiro_contracts.dart'
    show TenantRole;
import 'package:caopanheiro_core/caopanheiro_core.dart'
    show NetworkException, SessionAccessException;
import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import '../../domain/models/pet.dart';
import '../../domain/models/pet_internal_note.dart';
import '../../state/app_scope.dart';
import '../pets/breed_field.dart' show PetTextDialog;

class CustomerPetNotesScreen extends StatefulWidget {
  const CustomerPetNotesScreen({
    super.key,
    required this.customerId,
    required this.pet,
    required this.sessionKey,
  });

  final String customerId;
  final Pet pet;
  final ({int revision, TenantRole? function}) sessionKey;

  @override
  State<CustomerPetNotesScreen> createState() => _CustomerPetNotesScreenState();
}

class _CustomerPetNotesScreenState extends State<CustomerPetNotesScreen> {
  final _notes = <PetInternalNote>[];
  String? _nextCursor;
  String? _error;
  String _draft = '';
  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  bool get _available {
    final controller = AppScope.of(context);
    return controller.sessionKey == widget.sessionKey &&
        controller.petInternalNotesAvailable;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !_available) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on SessionAccessException catch (error) {
      _notes.clear();
      _nextCursor = null;
      _loaded = false;
      _error = error.message;
    } on FormatException catch (error) {
      _error = error.message;
    } on NetworkException catch (error) {
      _error = error.message;
    } catch (_) {
      _error = 'Não foi possível confirmar a operação. Tente novamente.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load({String? cursor}) => _run(() async {
    final page = await AppScope.of(
      context,
    ).loadPetInternalNotes(widget.customerId, widget.pet.id, cursor: cursor);
    if (!mounted || !_available) return;
    if (cursor == null) _notes.clear();
    final ids = _notes.map((note) => note.id).toSet();
    _notes.addAll(page.items.where((note) => ids.add(note.id)));
    _nextCursor = page.nextCursor;
    _loaded = true;
  });

  Future<void> _add() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => PetTextDialog(
        title: 'Adicionar observação interna',
        message: 'Só a equipe do petshop vê esta observação.',
        label: 'Observação',
        initial: _draft,
        maxLength: 2000,
        maxLines: 4,
        minLength: 1,
        confirmLabel: 'Adicionar',
      ),
    );
    if (!mounted || value == null) return;
    _draft = value;
    await _run(() async {
      final note = await AppScope.of(
        context,
      ).addPetInternalNote(widget.customerId, widget.pet.id, value);
      if (!mounted || !_available) return;
      _draft = '';
      _notes.removeWhere((item) => item.id == note.id);
      _notes.insert(0, note);
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return FormScaffold(
      title: 'Observações internas',
      child: !_available
          ? const PermissionNotice(
              message: 'Entre com acesso ao petshop para ver as observações.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.pet.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy || !_loaded ? null : _add,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar observação'),
                ),
                if (_busy) const LinearProgressIndicator(),
                if (_error case final message?) ...[
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _load(),
                    child: const Text('Atualizar observações'),
                  ),
                ],
                if (_loaded && _notes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text('Nenhuma observação registrada.'),
                  ),
                for (final note in _notes)
                  Card(
                    child: ListTile(
                      title: Text(note.text),
                      subtitle: Text(
                        [
                          if (note.authorName.isNotEmpty) note.authorName,
                          localizations.formatShortDate(note.createdAt),
                          localizations.formatTimeOfDay(
                            TimeOfDay.fromDateTime(note.createdAt),
                          ),
                        ].join(' · '),
                      ),
                    ),
                  ),
                if (_nextCursor case final cursor?)
                  TextButton(
                    onPressed: _busy ? null : () => _load(cursor: cursor),
                    child: const Text('Carregar mais observações'),
                  ),
              ],
            ),
    );
  }
}
