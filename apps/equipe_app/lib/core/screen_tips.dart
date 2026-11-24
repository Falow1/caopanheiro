import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppTipsVisibility, AppTourTip;
import 'package:flutter/widgets.dart';

/// Screens of the Equipe with tips. The server keeps the same closed list
/// (backend/src/screen_tips.js): a new screen enters both, and a new button
/// or flow gets its tip here (CONTRIBUTING).
abstract final class TipScreens {
  static const agenda = 'TEAM_AGENDA';
  static const customers = 'TEAM_CUSTOMERS';
  static const services = 'TEAM_SERVICES';
  static const more = 'TEAM_MORE';
  static const profile = 'TEAM_PROFILE';
  static const appointment = 'TEAM_APPOINTMENT';
  static const booking = 'TEAM_BOOKING';
  static const customer = 'TEAM_CUSTOMER';
  static const inviteLink = 'TEAM_INVITE_LINK';
  static const plan = 'TEAM_PLAN';
  static const renewal = 'TEAM_RENEWAL';
  static const accessPaused = 'TEAM_ACCESS_PAUSED';
  static const dataExport = 'TEAM_EXPORT';
  static const proToday = 'PRO_TODAY';
  static const proAgenda = 'PRO_AGENDA';
  static const proProfile = 'PRO_PROFILE';
  static const proAppointment = 'PRO_APPOINTMENT';
  static const driverToday = 'DRIVER_TODAY';
  static const driverTransports = 'DRIVER_TRANSPORTS';
  static const driverHistory = 'DRIVER_HISTORY';
  static const driverProfile = 'DRIVER_PROFILE';
  static const driverTransport = 'DRIVER_TRANSPORT';

  static const all = [
    agenda,
    customers,
    services,
    more,
    profile,
    appointment,
    booking,
    customer,
    inviteLink,
    plan,
    renewal,
    accessPaused,
    dataExport,
    proToday,
    proAgenda,
    proProfile,
    proAppointment,
    driverToday,
    driverTransports,
    driverHistory,
    driverProfile,
    driverTransport,
  ];
}

/// Pages of an [IndexedStack]: only the selected one shows its tips.
List<Widget> tipTabs(int index, List<Widget> pages) => [
  for (var i = 0; i < pages.length; i++)
    AppTipsVisibility(visible: i == index, child: pages[i]),
];

/// Ids of the areas the tips highlight (AppTourTarget); in a list, the
/// topmost item on screen is the one highlighted.
abstract final class TipTargets {
  static const nav = 'team.nav';
  static const workforce = 'team.workforce';
  static const help = 'team.help';
  static const operations = 'team.operations';
  static const agendaDay = 'team.agenda.day';
  static const agendaFilters = 'team.agenda.filters';
  static const agendaCard = 'team.agenda.card';
  static const agendaNew = 'team.agenda.new';
  static const customersSearch = 'team.customers.search';
  static const customersCard = 'team.customers.card';
  static const customersNew = 'team.customers.new';
  static const servicesCard = 'team.services.card';
  static const servicesNew = 'team.services.new';
  static const moreTeam = 'team.more.team';
  static const appointmentStatus = 'team.appointment.status';
  static const appointmentTransport = 'team.appointment.transport';
  static const appointmentPets = 'team.appointment.pets';
  static const appointmentActions = 'team.appointment.actions';
  static const bookingSearch = 'team.booking.search';
  static const bookingCustomer = 'team.booking.customer';
  static const bookingNew = 'team.booking.new';
  static const customerEdit = 'team.customer.edit';
  static const customerNew = 'team.customer.new';
  static const moreInviteLink = 'team.more.inviteLink';
  static const morePayments = 'team.more.payments';
  static const inviteLinkCopy = 'team.inviteLink.copy';
  static const inviteLinkShare = 'team.inviteLink.share';
  static const inviteLinkManage = 'team.inviteLink.manage';
  static const inviteLinkReturns = 'team.inviteLink.returns';
  static const planCurrent = 'team.plan.current';
  static const planTenants = 'team.plan.tenants';
  static const planOptions = 'team.plan.options';
  static const planCancel = 'team.plan.cancel';
  static const planRenewal = 'team.plan.renewal';
  static const renewalValue = 'team.renewal.value';
  static const renewalMethods = 'team.renewal.methods';
  static const renewalPaid = 'team.renewal.paid';
  static const pausedShop = 'team.paused.shop';
  static const pausedActions = 'team.paused.actions';
  static const exportFiles = 'team.export.files';
  static const proDay = 'pro.agenda.day';
  static const proFilters = 'pro.agenda.filters';
  static const proTodayCard = 'pro.today.card';
  static const proAgendaCard = 'pro.agenda.card';
  static const proActions = 'pro.appointment.actions';
  static const driverNext = 'driver.today.next';
  static const driverAll = 'driver.today.all';
  static const driverPeriod = 'driver.transports.period';
  static const driverKind = 'driver.transports.kind';
  static const driverCard = 'driver.transports.card';
  static const driverHistoryCard = 'driver.history.card';
  static const driverAddress = 'driver.transport.address';
  static const driverAction = 'driver.transport.action';
  static const driverIncident = 'driver.transport.incident';
}

const _nav = AppTourTip(
  target: TipTargets.nav,
  title: 'Menu',
  text:
      'Troque de área por aqui. Cada área mostra as próprias dicas na primeira vez que você abre.',
);

const _help = AppTourTip(
  target: TipTargets.help,
  title: 'Rever dicas',
  text: 'Toque aqui quando quiser ver estas dicas de novo em todas as telas.',
);

const _workforce = AppTourTip(
  target: TipTargets.workforce,
  title: 'Função e empresa',
  text:
      'Troque a função em uso e, com mais de uma empresa, escolha de qual ver os dados.',
);

abstract final class TeamTips {
  static const agenda = [
    AppTourTip(
      target: TipTargets.agendaDay,
      title: 'Trocar dia',
      text: 'Toque no calendário para ver os atendimentos de outro dia.',
    ),
    AppTourTip(
      target: TipTargets.agendaFilters,
      title: 'Filtros',
      text:
          'Mostre só os agendamentos confirmados, com pet recebido, em atendimento ou finalizados.',
    ),
    AppTourTip(
      target: TipTargets.agendaCard,
      title: 'Agendamento',
      text:
          'Toque para abrir. Lá você registra o recebimento dos pets, inicia e finaliza o atendimento.',
    ),
    AppTourTip(
      target: TipTargets.agendaNew,
      title: 'Novo agendamento',
      text: 'Escolha o cliente, os pets, os serviços e o horário, e confirme.',
    ),
    _nav,
  ];

  static const customers = [
    AppTourTip(
      target: TipTargets.customersSearch,
      title: 'Buscar cliente',
      text: 'Procure pelo número do cadastro, pelo nome ou pelo telefone.',
    ),
    AppTourTip(
      target: TipTargets.customersCard,
      title: 'Cliente',
      text:
          'Toque para ver os dados, os pets e os próximos agendamentos, e para agendar.',
    ),
    AppTourTip(
      target: TipTargets.customersNew,
      title: 'Novo cliente',
      text: 'Cadastre o tutor e, em seguida, os pets dele.',
    ),
  ];

  static const services = [
    AppTourTip(
      target: TipTargets.servicesCard,
      title: 'Serviço',
      text:
          'Mostra a duração, o preço e se está ativo. Quem pode editar toca no serviço para alterar.',
    ),
    AppTourTip(
      target: TipTargets.servicesNew,
      title: 'Novo serviço',
      text:
          'Cadastre o serviço com nome, duração e preço para usar nos agendamentos.',
    ),
  ];

  static const more = [
    _workforce,
    AppTourTip(
      target: TipTargets.moreInviteLink,
      title: 'Link de convite',
      text:
          'O link fixo do petshop: quem abrir cria a conta ou entra e já fica cadastrado como cliente.',
    ),
    AppTourTip(
      target: TipTargets.moreTeam,
      title: 'Gestão do petshop',
      text:
          'Em Equipe ficam usuários, profissionais e disponibilidade; em Funcionamento, horário, bloqueios e transporte.',
    ),
    AppTourTip(
      target: TipTargets.morePayments,
      title: 'Receber pelo app',
      text:
          'Em breve, o tutor vai poder pagar pelo app com Pix, cartão ou boleto. Por enquanto, receba no petshop.',
    ),
    _help,
  ];

  static const profile = [
    _workforce,
    AppTourTip(
      target: TipTargets.operations,
      title: 'Operação',
      text: 'Transporte e bloqueios de agenda ficam aqui.',
    ),
    _help,
  ];

  static const appointment = [
    AppTourTip(
      target: TipTargets.appointmentStatus,
      title: 'Situação',
      text:
          'Mostra a etapa do agendamento: confirmado, pet recebido, em atendimento ou finalizado.',
    ),
    AppTourTip(
      target: TipTargets.appointmentTransport,
      title: 'Transporte',
      text:
          'Agende a busca ou a entrega dos pets e acompanhe os transportes deste agendamento.',
    ),
    AppTourTip(
      target: TipTargets.appointmentPets,
      title: 'Pets e serviços',
      text:
          'Cada pet aparece com os seus serviços. Com mais de um pet, dá para iniciar e finalizar cada um separadamente.',
    ),
    AppTourTip(
      target: TipTargets.appointmentActions,
      title: 'Ações',
      text:
          'Registre o recebimento dos pets, inicie e finalize o atendimento. Enquanto está confirmado, também dá para marcar Não compareceu, editar ou cancelar.',
    ),
  ];

  static const booking = [
    AppTourTip(
      target: TipTargets.bookingSearch,
      title: 'Buscar tutor',
      text:
          'Procure o tutor pelo número do cadastro, pelo nome ou pelo telefone.',
    ),
    AppTourTip(
      target: TipTargets.bookingCustomer,
      title: 'Selecionar',
      text:
          'Escolha o tutor para seguir: depois vêm os pets, os serviços, o horário e a confirmação.',
    ),
    AppTourTip(
      target: TipTargets.bookingNew,
      title: 'Novo tutor',
      text:
          'Se o tutor ainda não tem cadastro, crie aqui sem sair do agendamento.',
    ),
  ];

  static const customer = [
    AppTourTip(
      target: TipTargets.customerEdit,
      title: 'Editar tutor',
      text: 'Atualize o nome, o telefone e o e-mail do tutor.',
    ),
    AppTourTip(
      target: TipTargets.customerNew,
      title: 'Novo agendamento',
      text: 'Comece um agendamento já com este tutor escolhido.',
    ),
  ];

  static const plan = [
    AppTourTip(
      target: TipTargets.planCurrent,
      title: 'Sua assinatura',
      text:
          'Um plano cobre todos os seus petshops. Aqui ficam o valor, a renovação e o fim do teste.',
    ),
    AppTourTip(
      target: TipTargets.planRenewal,
      title: 'Pagar agora',
      text:
          'Perto da renovação e depois dela, veja o valor e como pagar. Depois de pagar, avise a plataforma em Já paguei.',
    ),
    AppTourTip(
      target: TipTargets.planTenants,
      title: 'Seus petshops',
      text:
          'Veja as pessoas em uso de cada petshop e exporte os dados de cada um. No plano pago, um petshop extra sai da assinatura com a devolução dos dias que faltam ou volta com a taxa proporcional.',
    ),
    AppTourTip(
      target: TipTargets.planOptions,
      title: 'Trocar de plano',
      text:
          'Veja o valor da troca antes de pedir: só os dias que faltam até a renovação. A plataforma confirma o pagamento e aplica.',
    ),
    AppTourTip(
      target: TipTargets.planCancel,
      title: 'Cancelar quando quiser',
      text:
          'Escolha entre o fim do ciclo ou agora, com a devolução dos dias restantes. O petshop escolhido segue no Grátis.',
    ),
  ];

  static const renewal = [
    AppTourTip(
      target: TipTargets.renewalValue,
      title: 'Valor e data',
      text:
          'O valor cobre 30 dias do plano e de todos os petshops da assinatura.',
    ),
    AppTourTip(
      target: TipTargets.renewalMethods,
      title: 'Como pagar',
      text:
          'Pix, cartão e boleto pelo app chegam em breve. Por enquanto, pague pelo combinado com a plataforma.',
    ),
    AppTourTip(
      target: TipTargets.renewalPaid,
      title: 'Já paguei',
      text:
          'Avise a plataforma depois de pagar. Quando ela confirmar, o plano ganha mais 30 dias e tudo volta na hora.',
    ),
  ];

  static const accessPaused = [
    AppTourTip(
      target: TipTargets.pausedShop,
      title: 'Acesso pausado',
      text:
          'Nada foi apagado: clientes, pets e agendamentos ficam guardados. A equipe vê que precisa falar com você.',
    ),
    AppTourTip(
      target: TipTargets.pausedActions,
      title: 'Renovar ou exportar',
      text:
          'Renove para tudo voltar na hora, ou exporte uma cópia dos dados para guardar.',
    ),
  ];

  static const dataExport = [
    AppTourTip(
      target: TipTargets.exportFiles,
      title: 'Arquivos dos dados',
      text:
          'Clientes, pets e agendamentos em planilhas. Salve cada um ou compartilhe os três. Cada exportação fica registrada.',
    ),
  ];

  static const inviteLink = [
    AppTourTip(
      target: TipTargets.inviteLinkCopy,
      title: 'Link do petshop',
      text:
          'Copie e divulgue no balcão, no WhatsApp e nas redes. Quem abrir cria a conta ou entra e já fica cadastrado aqui.',
    ),
    AppTourTip(
      target: TipTargets.inviteLinkShare,
      title: 'QR Code e pôster',
      text:
          'Baixe para imprimir ou guardar, ou compartilhe pelo WhatsApp. O pôster já traz o QR Code e os passos para o tutor.',
    ),
    AppTourTip(
      target: TipTargets.inviteLinkManage,
      title: 'Gerenciar o link',
      text:
          'Desative para parar novas entradas. Gerar novo link troca o endereço: o antigo e o que já foi impresso param de funcionar.',
    ),
    AppTourTip(
      target: TipTargets.inviteLinkReturns,
      title: 'Pedidos de retorno',
      text:
          'Quem este petshop desvinculou não entra direto pelo link: aprove ou recuse o pedido aqui.',
    ),
  ];

  static const proToday = [
    AppTourTip(
      target: TipTargets.proTodayCard,
      title: 'Atendimentos de hoje',
      text:
          'Toque no atendimento para abrir. Lá você inicia, registra observações e finaliza.',
    ),
    _nav,
  ];

  static const proAgenda = [
    AppTourTip(
      target: TipTargets.proDay,
      title: 'Selecionar data',
      text: 'Toque no calendário para ver os atendimentos de outro dia.',
    ),
    AppTourTip(
      target: TipTargets.proFilters,
      title: 'Filtros',
      text:
          'Mostre todos os atendimentos, só os pendentes ou só os finalizados.',
    ),
    AppTourTip(
      target: TipTargets.proAgendaCard,
      title: 'Atendimento',
      text: 'Toque para abrir os pets, os serviços e as orientações do tutor.',
    ),
  ];

  static const proAppointment = [
    AppTourTip(
      target: TipTargets.proActions,
      title: 'Ações do atendimento',
      text:
          'Inicie o atendimento, registre observações que o tutor também vê e finalize quando terminar.',
    ),
  ];

  static const driverToday = [
    AppTourTip(
      target: TipTargets.driverNext,
      title: 'Próximo transporte',
      text:
          'Mostra o próximo transporte com o botão da etapa atual. Em Ver detalhes ficam endereços e contatos.',
    ),
    AppTourTip(
      target: TipTargets.driverAll,
      title: 'Ver todos',
      text: 'Abre a lista completa dos transportes.',
    ),
    _nav,
  ];

  static const driverTransports = [
    AppTourTip(
      target: TipTargets.driverPeriod,
      title: 'Período',
      text: 'Escolha entre os transportes de hoje e atrasados ou os próximos.',
    ),
    AppTourTip(
      target: TipTargets.driverKind,
      title: 'Tipo',
      text: 'Filtre as coletas ou os retornos.',
    ),
    AppTourTip(
      target: TipTargets.driverCard,
      title: 'Transporte',
      text: 'Toque para abrir os endereços, os pets e as ações.',
    ),
  ];

  static const driverHistory = [
    AppTourTip(
      target: TipTargets.driverHistoryCard,
      title: 'Histórico',
      text: 'Os transportes encerrados ficam aqui para consulta.',
    ),
  ];

  static const driverTransport = [
    AppTourTip(
      target: TipTargets.driverAddress,
      title: 'Endereço',
      text: 'Use Abrir rota para a navegação e Ligar para falar com o contato.',
    ),
    AppTourTip(
      target: TipTargets.driverAction,
      title: 'Etapa do transporte',
      text:
          'O botão segue a etapa: iniciar o deslocamento, confirmar a coleta, iniciar o transporte e confirmar a entrega.',
    ),
    AppTourTip(
      target: TipTargets.driverIncident,
      title: 'Ocorrência',
      text: 'Registre qualquer imprevisto no caminho para a equipe acompanhar.',
    ),
  ];
}
