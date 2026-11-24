import 'package:equipe_app/modules/driver/domain/models.dart';

// Called by each repository at the original eager or lazy initialization point.
List<TransportJob> createInitialTransports() {
  final now = DateTime.now();
  DateTime at(int dayOffset, int hour, int minute) =>
      DateTime(now.year, now.month, now.day + dayOffset, hour, minute);

  const petShop = TransportAddress(
    name: 'Pet Feliz',
    street: 'Av. Principal, 500',
    district: 'Jardim das Américas',
    phone: '(65) 3321-4400',
  );
  const animalCenter = TransportAddress(
    name: 'Animal Center',
    street: 'Av. Couto Magalhães, 880',
    district: 'Centro',
    phone: '(65) 3344-7788',
  );
  const joao = TransportAddress(
    name: 'João Silva',
    street: 'Rua das Flores, 123',
    district: 'Centro',
    phone: '(65) 99911-2233',
  );
  const ana = TransportAddress(
    name: 'Ana Souza',
    street: 'Rua dos Ipês, 45',
    district: 'Bosque da Saúde',
    phone: '(65) 99877-6655',
  );
  const marcos = TransportAddress(
    name: 'Marcos Lima',
    street: 'Av. das Palmeiras, 710',
    district: 'Santa Rosa',
    phone: '(65) 99700-1122',
  );
  const thor = TransportPet(
    name: 'Thor',
    breed: 'Golden Retriever',
    size: 'Grande',
  );
  const mel = TransportPet(name: 'Mel', breed: 'Shih-tzu', size: 'Pequeno');
  const bob = TransportPet(name: 'Bob', breed: 'Vira-lata', size: 'Médio');

  return [
    TransportJob(
      id: 'TRA-1042',
      tenantId: 'pet-feliz',
      appointmentId: 'AGD-500',
      type: TransportType.pickup,
      scheduledAt: at(0, 9, 30),
      status: TransportStatus.assigned,
      origin: joao,
      destination: petShop,
      pets: const [thor],
      notes:
          'Thor possui dificuldade para entrar no veículo. Utilizar a guia do tutor.',
      events: [
        TransportEvent(
          status: TransportStatus.assigned,
          createdAt: at(-1, 16, 10),
          actor: 'Fernanda · Atendente',
        ),
      ],
    ),
    TransportJob(
      id: 'TRA-1043',
      tenantId: 'pet-feliz',
      appointmentId: 'AGD-501',
      type: TransportType.returnTrip,
      scheduledAt: at(0, 11, 0),
      status: TransportStatus.petCollected,
      origin: petShop,
      destination: ana,
      pets: const [mel],
      notes: 'Entregar a Mel diretamente para Ana.',
      startedAt: at(0, 10, 48),
      collectedAt: at(0, 10, 55),
      events: [
        TransportEvent(
          status: TransportStatus.assigned,
          createdAt: at(-1, 16, 15),
          actor: 'Fernanda · Atendente',
        ),
        TransportEvent(
          status: TransportStatus.goingToOrigin,
          createdAt: at(0, 10, 48),
          actor: 'Carlos Silva',
        ),
        TransportEvent(
          status: TransportStatus.petCollected,
          createdAt: at(0, 10, 55),
          actor: 'Carlos Silva',
        ),
      ],
    ),
    TransportJob(
      id: 'TRA-1044',
      tenantId: 'pet-feliz',
      appointmentId: 'AGD-502',
      type: TransportType.pickup,
      scheduledAt: at(0, 14, 30),
      status: TransportStatus.goingToOrigin,
      origin: marcos,
      destination: petShop,
      pets: const [bob],
      notes: 'Interfonar no apartamento 304.',
      startedAt: at(0, 14, 5),
      events: [
        TransportEvent(
          status: TransportStatus.assigned,
          createdAt: at(-1, 16, 20),
          actor: 'Fernanda · Atendente',
        ),
        TransportEvent(
          status: TransportStatus.goingToOrigin,
          createdAt: at(0, 14, 5),
          actor: 'Carlos Silva',
        ),
      ],
    ),
    TransportJob(
      id: 'TRA-1045',
      tenantId: 'pet-feliz',
      appointmentId: 'AGD-503',
      type: TransportType.returnTrip,
      scheduledAt: at(1, 17, 0),
      status: TransportStatus.assigned,
      origin: petShop,
      destination: joao,
      pets: const [thor],
      notes: 'Retorno liberado após a finalização do atendimento.',
      events: [
        TransportEvent(
          status: TransportStatus.assigned,
          createdAt: at(0, 8, 0),
          actor: 'Fernanda · Atendente',
        ),
      ],
    ),
    TransportJob(
      id: 'TRA-1036',
      tenantId: 'pet-feliz',
      appointmentId: 'AGD-491',
      type: TransportType.pickup,
      scheduledAt: at(-1, 9, 30),
      status: TransportStatus.delivered,
      origin: ana,
      destination: petShop,
      pets: const [mel],
      notes: 'Usar caixa de transporte.',
      startedAt: at(-1, 9, 10),
      collectedAt: at(-1, 9, 32),
      deliveredAt: at(-1, 10, 12),
      events: [
        TransportEvent(
          status: TransportStatus.assigned,
          createdAt: at(-2, 15, 0),
          actor: 'Fernanda · Atendente',
        ),
        TransportEvent(
          status: TransportStatus.goingToOrigin,
          createdAt: at(-1, 9, 10),
          actor: 'Carlos Silva',
        ),
        TransportEvent(
          status: TransportStatus.petCollected,
          createdAt: at(-1, 9, 32),
          actor: 'Carlos Silva',
        ),
        TransportEvent(
          status: TransportStatus.inTransit,
          createdAt: at(-1, 9, 35),
          actor: 'Carlos Silva',
        ),
        TransportEvent(
          status: TransportStatus.delivered,
          createdAt: at(-1, 10, 12),
          actor: 'Carlos Silva',
        ),
      ],
    ),
    TransportJob(
      id: 'TRA-2031',
      tenantId: 'animal-center',
      appointmentId: 'AGD-881',
      type: TransportType.pickup,
      scheduledAt: at(0, 16, 0),
      status: TransportStatus.assigned,
      origin: joao,
      destination: animalCenter,
      pets: const [thor],
      notes: 'Confirmar chegada pelo telefone.',
      events: [
        TransportEvent(
          status: TransportStatus.assigned,
          createdAt: at(-1, 14, 0),
          actor: 'Ana · Gestora',
        ),
      ],
    ),
  ];
}

DriverProfile createInitialDriverProfile() => const DriverProfile(
  id: 'driver-01',
  name: 'Carlos Silva',
  email: 'carlos@entregas.com',
  phone: '(65) 99988-7766',
);

List<TenantMembership> createInitialMemberships() => const [
  TenantMembership(tenantId: 'pet-feliz', tenantName: 'Pet Feliz'),
  TenantMembership(tenantId: 'animal-center', tenantName: 'Animal Center'),
];
