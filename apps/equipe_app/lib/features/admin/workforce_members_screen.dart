import '../../domain/models/management_permissions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:caopanheiro_core/caopanheiro_core.dart' show newRecordId;
import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppConfirmTone, showAppConfirmation;
import '../../domain/models.dart';
import '../../state/app_scope.dart';
import 'staff_unlink_dialog.dart';

class WorkforceMembersScreen extends StatefulWidget {
  const WorkforceMembersScreen({super.key, this.management = false});
  final bool management;
  @override
  State<WorkforceMembersScreen> createState() => _WorkforceMembersScreenState();
}

class _WorkforceMembersScreenState extends State<WorkforceMembersScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _load() async {
    final c = AppScope.of(context);
    if (c.user?.canManagePeople != true) return;
    final values = await c.workforceMembers();
    if (mounted && values != null) setState(() => _members = values);
  }

  Future<void> _invite() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StaffInviteFormScreen(management: widget.management),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _revoke(Map<String, dynamic> member) async {
    final c = AppScope.of(context),
        companyId = AppScope.of(context).company?.id;
    final confirmed = await showAppConfirmation(
      context,
      title: 'Revogar convite?',
      message:
          'O convite para ${c.company?.name ?? 'este petshop'} não poderá mais ser usado.',
      confirmLabel: 'Revogar',
      tone: AppConfirmTone.danger,
    );
    if (!mounted || !confirmed || c.company?.id != companyId) return;
    if (await c.revokeWorkforceInvitation(member['id'] as String) && mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    if (c.user?.canManagePeople != true) {
      return const Scaffold(
        body: Center(child: Text('Acesso exclusivo do gestor principal.')),
      );
    }
    final items = _members.where((m) {
      final roles =
          (m['invitationPending'] == true ? m['invitedRoles'] : m['roles'])
              as List? ??
          [];
      return widget.management
          ? roles.contains('MANAGER')
          : !roles.contains('MANAGER');
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.management ? 'Usuários de gestão' : 'Equipe e funções',
        ),
        actions: [
          IconButton(
            tooltip: widget.management
                ? 'Convidar usuário de gestão'
                : 'Convidar funcionário',
            onPressed: c.busy || c.readOnly ? null : _invite,
            icon: const Icon(Icons.person_add_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              c.company?.name ?? '',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              widget.management
                  ? 'Os usuários de gestão operam este petshop. Somente o gestor principal administra os vínculos.'
                  : 'Você pode ter vários atendentes, profissionais e entregadores, inclusive pessoas com múltiplas funções, conforme o plano. Convide por link. Cada pessoa preenche os próprios dados. Aqui você administra somente as funções e o vínculo com este petshop.',
            ),
            const SizedBox(height: 12),
            if (c.error != null) Text(c.error!),
            if (c.busy) const LinearProgressIndicator(),
            for (final m in items)
              Card(
                child: ListTile(
                  title: Text(m['name'] as String? ?? 'Convite pendente'),
                  subtitle: Text(
                    m['invitationPending'] == true
                        ? (m['invitationExpired'] == true
                              ? 'Convite expirado'
                              : 'Convite pendente')
                        : (m['principal'] == true
                              ? 'Gestor principal'
                              : ((m['roles'] as List? ?? [])
                                    .map(
                                      (r) =>
                                          TenantRole.fromApi(r as String).label,
                                    )
                                    .join(' · '))),
                  ),
                  trailing: m['invitationPending'] == true
                      ? IconButton(
                          tooltip: 'Revogar convite',
                          onPressed: c.busy || c.readOnly
                              ? null
                              : () => _revoke(m),
                          icon: const Icon(Icons.link_off),
                        )
                      : (m['principal'] == true
                            ? const Icon(Icons.verified_user_outlined)
                            : const Icon(Icons.chevron_right)),
                  onTap:
                      c.busy ||
                          m['invitationPending'] == true ||
                          m['principal'] == true
                      ? null
                      : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WorkforceMemberAccessScreen(
                                member: m,
                                management: widget.management,
                              ),
                            ),
                          );
                          if (mounted) await _load();
                        },
                ),
              ),
            if (!c.busy && items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nenhum vínculo encontrado.'),
              ),
          ],
        ),
      ),
    );
  }
}

class StaffInviteFormScreen extends StatefulWidget {
  const StaffInviteFormScreen({
    super.key,
    this.management = false,
    this.professionalId,
    this.professional = false,
  });
  final bool management, professional;
  final String? professionalId;
  @override
  State<StaffInviteFormScreen> createState() => _StaffInviteFormScreenState();
}

class _StaffInviteFormScreenState extends State<StaffInviteFormScreen> {
  final _roles = <TenantRole>{};
  final _permissions = managementPermissionLabels.keys.toSet();
  Set<String>? _companyIds;
  late final String _token = newRecordId();
  @override
  void initState() {
    super.initState();
    if (widget.professional || widget.professionalId != null) {
      _roles.add(TenantRole.professional);
    }
  }

  Future<void> _generate() async {
    final c = AppScope.of(context);
    if (!widget.management && _roles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha ao menos uma função.')),
      );
      return;
    }
    if (widget.management && _permissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha ao menos uma permissão.')),
      );
      return;
    }
    final selectedCompanies =
        _companyIds ?? {if (c.company != null) c.company!.id};
    final eligible = c.companies
        .where((company) => company.user.isPrincipal)
        .map((company) => company.id)
        .toSet();
    if (widget.management &&
        (selectedCompanies.isEmpty ||
            !eligible.containsAll(selectedCompanies))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecione ao menos uma empresa em que você é principal.',
          ),
        ),
      );
      return;
    }
    final link = await c.createStaffLink({
      if (widget.management)
        'tenantId': selectedCompanies.contains(c.company?.id)
            ? c.company!.id
            : selectedCompanies.first,
      if (widget.management) 'tenantIds': selectedCompanies.toList(),
      'token': _token,
      'kind': widget.management ? 'MANAGEMENT' : 'OPERATIONAL',
      'roles': widget.management
          ? ['MANAGER']
          : _roles.map((r) => r.apiValue).toList(),
      'professionalId': widget.professionalId,
      if (widget.management) 'managementPermissions': _permissions.toList(),
    });
    if (!mounted || link == null) return;
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Convite pronto para compartilhar'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'O link vale por 24 horas e pode ser usado uma vez. A pessoa preencherá os próprios dados. Copie agora; se perder o link, revogue o convite e gere outro.',
              ),
              const SizedBox(height: 16),
              SelectableText(link),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Concluir'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (dialog.mounted) {
                ScaffoldMessenger.of(
                  dialog,
                ).showSnackBar(const SnackBar(content: Text('Link copiado.')));
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar link'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    if (c.user?.canManagePeople != true) {
      return const Scaffold(
        body: Center(child: Text('Acesso exclusivo do gestor principal.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.management
              ? 'Convidar usuário de gestão'
              : 'Convidar funcionário',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              c.company?.name ?? '',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const Text(
              'Gere o convite e compartilhe o link com a pessoa. Você não precisa informar nem consultar o e-mail dela.',
            ),
            const SizedBox(height: 16),
            if (widget.management) ...[
              if (c.companies
                      .where((company) => company.user.isPrincipal)
                      .length >
                  1) ...[
                const Text('Empresas para este convite'),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Selecionar todas as empresas'),
                  value:
                      (_companyIds ?? {c.company!.id}).length ==
                      c.companies
                          .where((company) => company.user.isPrincipal)
                          .length,
                  onChanged: c.busy
                      ? null
                      : (value) => setState(
                          () => _companyIds = value == true
                              ? c.companies
                                    .where(
                                      (company) => company.user.isPrincipal,
                                    )
                                    .map((company) => company.id)
                                    .toSet()
                              : <String>{},
                        ),
                ),
                for (final company in c.companies.where(
                  (company) => company.user.isPrincipal,
                ))
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(company.name),
                    value: (_companyIds ?? {c.company!.id}).contains(
                      company.id,
                    ),
                    onChanged: c.busy
                        ? null
                        : (value) => setState(() {
                            _companyIds ??= {c.company!.id};
                            if (value == true) {
                              _companyIds!.add(company.id);
                            } else {
                              _companyIds!.remove(company.id);
                            }
                          }),
                  ),
              ],
              const Text(
                'O convidado será gestor delegado. Mesmo com acesso completo, somente você continua como principal. A consulta operacional é permitida; as escolhas abaixo autorizam alterações por área. Convites, permissões e desvinculações ficam com o principal.',
              ),
              _PermissionChoices(
                selected: _permissions,
                enabled: !c.busy && !c.readOnly,
                onChanged: () => setState(() {}),
              ),
            ] else
              for (final role in [
                TenantRole.attendant,
                TenantRole.professional,
                TenantRole.driver,
              ])
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(role.label),
                  value: _roles.contains(role),
                  onChanged:
                      c.busy ||
                          widget.professionalId != null &&
                              role == TenantRole.professional
                      ? null
                      : (value) => setState(() {
                          if (value == true) {
                            _roles.add(role);
                          } else {
                            _roles.remove(role);
                          }
                        }),
                ),
            if (c.error != null) Text(c.error!),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: c.busy || c.readOnly ? null : _generate,
              child: const Text('Gerar link de convite'),
            ),
          ],
        ),
      ),
    );
  }
}

class WorkforceMemberAccessScreen extends StatefulWidget {
  const WorkforceMemberAccessScreen({
    super.key,
    required this.member,
    required this.management,
  });
  final Map<String, dynamic> member;
  final bool management;
  @override
  State<WorkforceMemberAccessScreen> createState() =>
      WorkforceMemberAccessScreenState();
}

class WorkforceMemberAccessScreenState
    extends State<WorkforceMemberAccessScreen> {
  late final Set<TenantRole> _roles = (widget.member['roles'] as List)
      .where((r) => ['ATTENDANT', 'PROFESSIONAL', 'DRIVER'].contains(r))
      .map((r) => TenantRole.fromApi(r as String))
      .toSet();
  late final Set<String> _permissions =
      ((widget.member['managementPermissions'] as List?)?.cast<String>() ??
              managementPermissionLabels.keys.toList())
          .toSet();
  Future<void> _savePermissions() async {
    final c = AppScope.of(context),
        companyId = AppScope.of(context).company?.id;
    if (_permissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha ao menos uma permissão.')),
      );
      return;
    }
    final confirmed = await showAppConfirmation(
      context,
      title: 'Alterar permissões?',
      message:
          'O acesso de ${widget.member['name']} neste petshop seguirá as áreas selecionadas. A pessoa continuará como gestora delegada.',
      confirmLabel: 'Alterar permissões',
    );
    if (!mounted || !confirmed || c.company?.id != companyId) return;
    if (await c.saveWorkforceRoles({
          'userId': widget.member['id'],
          'managementPermissions': _permissions.toList(),
        }) &&
        mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _transfer() async {
    final c = AppScope.of(context), source = c.company;
    if (source == null || !source.user.isPrincipal) return;
    final destinations = c.companies
        .where((company) => company.id != source.id && company.user.isPrincipal)
        .toList();
    final destination = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Transferir funcionário'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Escolha a empresa de destino. As funções operacionais serão transferidas juntas. O histórico permanece na origem e a disponibilidade deve ser configurada no destino.',
                ),
                const SizedBox(height: 16),
                for (final company in destinations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialog, company.id),
                      child: Text(company.name),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Voltar'),
          ),
        ],
      ),
    );
    if (!mounted || destination == null || c.company?.id != source.id) return;
    final destinationName = destinations
        .firstWhere((company) => company.id == destination)
        .name;
    final confirmed = await showAppConfirmation(
      context,
      title: 'Confirmar transferência?',
      message:
          'Funcionário: ${widget.member['name']}\nOrigem: ${source.name}\nDestino: $destinationName\n\nO acesso de equipe na origem será retirado. Conta, histórico, vínculo de Tutor e outras empresas serão preservados. Tarefas abertas impedem a transferência.',
      confirmLabel: 'Transferir',
    );
    if (!mounted || !confirmed || c.company?.id != source.id) return;
    if (await c.saveWorkforceRoles({
          'userId': widget.member['id'],
          'destinationTenantId': destination,
          'confirmed': true,
        }) &&
        mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _save() async {
    final c = AppScope.of(context);
    if (_roles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Para retirar o acesso, use Desvincular.'),
        ),
      );
      return;
    }
    if (await c.saveWorkforceRoles({
          'userId': widget.member['id'],
          'roles': _roles.map((r) => r.apiValue).toList(),
        }) &&
        mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context),
        name = widget.member['name'] as String? ?? 'Integrante';
    return Scaffold(
      appBar: AppBar(title: const Text('Vínculo com o petshop')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(name, style: Theme.of(context).textTheme.headlineSmall),
            Text(c.company?.name ?? ''),
            const SizedBox(height: 16),
            const Text(
              'Os dados pessoais são preenchidos pela própria pessoa e não podem ser editados pelo gestor.',
            ),
            const SizedBox(height: 16),
            if (widget.management) ...[
              const Text(
                'Gestor delegado. Acesso completo não concede a função de principal. A consulta operacional é permitida; selecione as áreas que a pessoa pode alterar.',
              ),
              _PermissionChoices(
                selected: _permissions,
                enabled: !c.busy && !c.readOnly,
                onChanged: () => setState(() {}),
              ),
              FilledButton(
                onPressed: c.busy || c.readOnly ? null : _savePermissions,
                child: const Text('Salvar permissões'),
              ),
            ] else ...[
              for (final role in [
                TenantRole.attendant,
                TenantRole.professional,
                TenantRole.driver,
              ])
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(role.label),
                  value: _roles.contains(role),
                  subtitle:
                      role == TenantRole.professional &&
                          !(widget.member['roles'] as List).contains(
                            'PROFESSIONAL',
                          )
                      ? const Text(
                          'Para habilitar, desvincule e gere um novo convite com essa função.',
                        )
                      : null,
                  onChanged:
                      c.busy ||
                          c.readOnly ||
                          role == TenantRole.professional &&
                              !(widget.member['roles'] as List).contains(
                                'PROFESSIONAL',
                              )
                      ? null
                      : (value) => setState(() {
                          if (value == true) {
                            _roles.add(role);
                          } else {
                            _roles.remove(role);
                          }
                        }),
                ),
              FilledButton(
                onPressed: c.busy || c.readOnly ? null : _save,
                child: const Text('Salvar funções'),
              ),
            ],
            const SizedBox(height: 16),
            if (!widget.management &&
                (widget.member['roles'] as List? ?? []).any(
                  (role) =>
                      ['ATTENDANT', 'PROFESSIONAL', 'DRIVER'].contains(role),
                ) &&
                c.companies
                        .where((company) => company.user.isPrincipal)
                        .length >
                    1)
              OutlinedButton.icon(
                onPressed: c.busy || c.readOnly ? null : _transfer,
                icon: const Icon(Icons.drive_file_move_outlined),
                label: const Text('Transferir para outra empresa'),
              ),
            OutlinedButton.icon(
              onPressed: c.busy || c.readOnly
                  ? null
                  : () async {
                      if (await unlinkStaffFromPetshop(
                            context,
                            name: name,
                            target: {'userId': widget.member['id']},
                          ) &&
                          context.mounted) {
                        Navigator.pop(context, true);
                      }
                    },
              icon: const Icon(Icons.person_remove_outlined),
              label: const Text('Desvincular do petshop'),
            ),
            if (c.error != null) Text(c.error!),
          ],
        ),
      ),
    );
  }
}

class _PermissionChoices extends StatelessWidget {
  const _PermissionChoices({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });
  final Set<String> selected;
  final bool enabled;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Acesso completo à gestão'),
        value: selected.length == managementPermissionLabels.length,
        onChanged: !enabled
            ? null
            : (value) {
                selected.clear();
                if (value == true) {
                  selected.addAll(managementPermissionLabels.keys);
                }
                onChanged();
              },
      ),
      for (final entry in managementPermissionLabels.entries)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(entry.value),
          value: selected.contains(entry.key),
          onChanged: !enabled
              ? null
              : (value) {
                  if (value == true) {
                    selected.add(entry.key);
                  } else {
                    selected.remove(entry.key);
                  }
                  onChanged();
                },
        ),
    ],
  );
}
