import 'package:caopanheiro_design_system/caopanheiro_design_system.dart'
    show AppTipsVisibility, AppTourTip, AppWindowClass, appWindowClassOf;
import 'package:flutter/widgets.dart';

/// Screens of the Tutor with tips. The server keeps the same closed list
/// (backend/src/screen_tips.js): a new screen enters both, and a new button
/// or flow gets its tip here (CONTRIBUTING).
abstract final class TipScreens {
  static const home = 'TUTOR_HOME';
  static const booking = 'TUTOR_BOOKING';
  static const pets = 'TUTOR_PETS';
  static const profile = 'TUTOR_PROFILE';
  static const bookingPets = 'TUTOR_BOOKING_PETS';
  static const bookingSchedule = 'TUTOR_BOOKING_SCHEDULE';
  static const bookingConfirm = 'TUTOR_BOOKING_CONFIRM';
  static const appointment = 'TUTOR_APPOINTMENT';

  static const all = [
    home,
    booking,
    pets,
    profile,
    bookingPets,
    bookingSchedule,
    bookingConfirm,
    appointment,
  ];
}

/// Pages of an [IndexedStack]: only the selected one shows its tips.
List<Widget> tipTabs(int index, List<Widget> pages) => [
  for (var i = 0; i < pages.length; i++)
    AppTipsVisibility(visible: i == index, child: pages[i]),
];

/// Tips said otherwise on wide windows, by target: there the days are an
/// open month to click, not a strip to slide.
const _wideTexts = {TipTargets.scheduleDays: 'Clique no dia do atendimento.'};

/// [tips] as said on this window. On wide windows the person uses a mouse,
/// so a tip that starts with "Toque" says "Clique", and the ones of
/// [_wideTexts] say what the wide design shows; nothing else changes.
List<AppTourTip> tutorTips(BuildContext context, List<AppTourTip> tips) {
  if (appWindowClassOf(context) == AppWindowClass.compact) return tips;
  return [
    for (final tip in tips)
      if (_wideTexts[tip.target] case final text?)
        AppTourTip(target: tip.target!, title: tip.title, text: text)
      else if (!tip.text.startsWith('Toque'))
        tip
      else if (tip.target case final target?)
        AppTourTip(
          target: target,
          title: tip.title,
          text: 'Clique${tip.text.substring('Toque'.length)}',
        )
      else
        AppTourTip.note(
          title: tip.title,
          text: 'Clique${tip.text.substring('Toque'.length)}',
        ),
  ];
}

/// Ids of the areas the tips highlight (AppTourTarget); in a list, the
/// topmost item on screen is the one highlighted.
abstract final class TipTargets {
  static const nav = 'tutor.nav';

  /// Atualizar button, only on wide windows (no pulling with a mouse).
  static const refresh = 'tutor.refresh';
  static const help = 'tutor.help';
  static const homeNext = 'tutor.home.next';
  static const homeHistory = 'tutor.home.history';
  static const homeNew = 'tutor.home.new';

  /// Shortcuts to the pets on the Início, only on wide windows.
  static const homePets = 'tutor.home.pets';
  static const bookingStart = 'tutor.booking.start';
  static const petsCard = 'tutor.pets.card';
  static const petsAdd = 'tutor.pets.add';
  static const profileEdit = 'tutor.profile.edit';
  static const profileHistory = 'tutor.profile.history';
  static const steps = 'tutor.booking.steps';

  /// Summary beside the booking steps, only on wide windows.
  static const bookingSummary = 'tutor.booking.summary';
  static const bookingPet = 'tutor.booking.pet';
  static const bookingOtherPet = 'tutor.booking.other_pet';
  static const scheduleDays = 'tutor.schedule.days';
  static const scheduleOtherDate = 'tutor.schedule.other_date';
  static const scheduleProfessional = 'tutor.schedule.professional';
  static const scheduleTimes = 'tutor.schedule.times';
  // The card of the review, or the summary beside the steps on wide windows.
  static const confirmSummary = 'tutor.confirm.summary';
  static const confirmButton = 'tutor.confirm.button';
  static const appointmentReschedule = 'tutor.appointment.reschedule';
  static const appointmentTransport = 'tutor.appointment.transport';
  static const appointmentCancel = 'tutor.appointment.cancel';
}

abstract final class TutorTips {
  static const home = [
    AppTourTip(
      target: TipTargets.homeNext,
      title: 'Próximo agendamento',
      text:
          'Toque para ver os detalhes, remarcar, pedir transporte ou cancelar.',
    ),
    AppTourTip(
      target: TipTargets.homeHistory,
      title: 'Histórico',
      text: 'Os atendimentos anteriores ficam em Histórico.',
    ),
    // On wide windows, the button of the side bar.
    AppTourTip(
      target: TipTargets.homeNew,
      title: 'Novo agendamento',
      text:
          'Escolha os pets, os serviços e o horário. Você revisa tudo antes de confirmar.',
    ),
    // This one and Atualizar only exist on wide windows.
    AppTourTip(
      target: TipTargets.homePets,
      title: 'Seus pets',
      text: 'Clique em um pet para ver ou editar o cadastro.',
    ),
    AppTourTip(
      target: TipTargets.refresh,
      title: 'Atualizar',
      text:
          'Busca de novo os seus agendamentos, os pets e os avisos do petshop.',
    ),
    AppTourTip(
      target: TipTargets.nav,
      title: 'Menu',
      text:
          'Agendar, Pets e Perfil ficam aqui. Cada área mostra as próprias dicas na primeira vez que você abre.',
    ),
  ];

  static const booking = [
    AppTourTip(
      target: TipTargets.bookingStart,
      title: 'Começar',
      text: 'Toque para agendar: pets, serviços, horário e confirmação.',
    ),
  ];

  static const pets = [
    AppTourTip(
      target: TipTargets.petsCard,
      title: 'Seus pets',
      text: 'Cada pet cadastrado aparece aqui com espécie e raça.',
    ),
    AppTourTip(
      target: TipTargets.petsAdd,
      title: 'Adicionar pet',
      text: 'Cadastre um novo pet para poder agendar para ele.',
    ),
  ];

  static const profile = [
    AppTourTip(
      target: TipTargets.profileEdit,
      title: 'Editar dados',
      text: 'Atualize o seu nome e o seu telefone.',
    ),
    AppTourTip(
      target: TipTargets.profileHistory,
      title: 'Histórico de atendimentos',
      text: 'Veja os atendimentos já realizados.',
    ),
    AppTourTip(
      target: TipTargets.help,
      title: 'Rever dicas',
      text:
          'Toque aqui quando quiser ver estas dicas de novo em todas as telas.',
    ),
  ];

  static const bookingPets = [
    AppTourTip(
      target: TipTargets.steps,
      title: 'Etapas',
      text: 'Mostra em que passo do agendamento você está.',
    ),
    AppTourTip(
      target: TipTargets.bookingPet,
      title: 'Escolha os pets',
      text: 'Toque para marcar. Dá para escolher mais de um pet.',
    ),
    AppTourTip(
      target: TipTargets.bookingOtherPet,
      title: 'Cadastrar outro pet',
      text:
          'Se o pet ainda não está na lista, cadastre sem sair do agendamento.',
    ),
    // Only on wide windows, where the summary sits beside the steps.
    AppTourTip(
      target: TipTargets.bookingSummary,
      title: 'Resumo',
      text:
          'Aqui aparece o que você já escolheu e o total. O botão para continuar fica embaixo.',
    ),
  ];

  static const bookingSchedule = [
    AppTourTip(
      target: TipTargets.scheduleDays,
      title: 'Dia',
      text: 'Deslize para escolher o dia do atendimento.',
    ),
    AppTourTip(
      target: TipTargets.scheduleOtherDate,
      title: 'Outra data',
      text: 'Abre o calendário para uma data mais distante.',
    ),
    AppTourTip(
      target: TipTargets.scheduleProfessional,
      title: 'Profissional',
      text: 'Escolha um profissional ou deixe qualquer um.',
    ),
    AppTourTip(
      target: TipTargets.scheduleTimes,
      title: 'Horários',
      text: 'Toque no horário que preferir e continue.',
    ),
  ];

  static const bookingConfirm = [
    AppTourTip(
      target: TipTargets.confirmSummary,
      title: 'Resumo',
      text: 'Confira os pets, os serviços, a data e o valor.',
    ),
    AppTourTip(
      target: TipTargets.confirmButton,
      title: 'Confirmar',
      text:
          'A disponibilidade é conferida de novo quando você confirma. Para mudar algo, use Voltar e editar.',
    ),
  ];

  static const appointment = [
    AppTourTip(
      target: TipTargets.appointmentReschedule,
      title: 'Remarcar',
      text:
          'Escolha outra data e horário. O horário atual só é liberado depois que você confirma a remarcação.',
    ),
    AppTourTip(
      target: TipTargets.appointmentTransport,
      title: 'Solicitar transporte',
      text: 'Peça ao petshop a busca ou a entrega do pet.',
    ),
    AppTourTip(
      target: TipTargets.appointmentCancel,
      title: 'Cancelar agendamento',
      text: 'Cancela o agendamento depois que você confirma.',
    ),
  ];
}
