import 'package:equipe_app/modules/professional/domain/models.dart';

// Called by each repository at the original eager or lazy initialization point.
Professional createInitialProfessional() => const Professional(
  id: 'pro-1',
  name: 'Carlos Mendes',
  role: 'Tosador',
  email: 'carlos@empresa.com',
  phone: '(65) 99845-1170',
);

List<Appointment> createInitialAppointments() => [
  Appointment(
    id: 'a-1',
    startsAt: DateTime(2026, 9, 20, 8),
    pet: const Pet(
      id: 'p-1',
      name: 'Thor',
      breed: 'Golden Retriever',
      size: 'Grande',
      notes: 'Prefere secagem com temperatura baixa.',
    ),
    services: const [
      ServiceItem(name: 'Banho', durationMinutes: 60),
      ServiceItem(name: 'Tosa', durationMinutes: 90),
    ],
    status: AppointmentStatus.petReceived,
    tutorName: 'João Silva',
  ),
  Appointment(
    id: 'a-2',
    startsAt: DateTime(2026, 9, 20, 10, 30),
    pet: const Pet(
      id: 'p-2',
      name: 'Mel',
      breed: 'Shih-tzu',
      size: 'Pequeno',
      notes: 'Usar shampoo hipoalergênico.',
    ),
    services: const [ServiceItem(name: 'Banho', durationMinutes: 60)],
    status: AppointmentStatus.confirmed,
    tutorName: 'Ana Souza',
  ),
  Appointment(
    id: 'a-3',
    startsAt: DateTime(2026, 9, 20, 14),
    pet: const Pet(
      id: 'p-3',
      name: 'Bob',
      breed: 'Poodle',
      size: 'Médio',
      notes: 'Sensível nas patas traseiras.',
    ),
    services: const [ServiceItem(name: 'Tosa', durationMinutes: 90)],
    status: AppointmentStatus.inProgress,
    tutorName: 'Marina Alves',
    observations: [
      ServiceObservation(
        text: 'Pequeno nó atrás da orelha direita.',
        createdAt: DateTime(2026, 9, 20, 14, 12),
      ),
    ],
  ),
  Appointment(
    id: 'a-4',
    startsAt: DateTime(2026, 9, 21, 9),
    pet: const Pet(
      id: 'p-4',
      name: 'Lola',
      breed: 'Yorkshire',
      size: 'Pequeno',
    ),
    services: const [
      ServiceItem(name: 'Banho', durationMinutes: 60),
      ServiceItem(name: 'Hidratação', durationMinutes: 30),
    ],
    status: AppointmentStatus.confirmed,
    tutorName: 'Beatriz Ramos',
  ),
  Appointment(
    id: 'a-5',
    startsAt: DateTime(2026, 9, 22, 15),
    pet: const Pet(
      id: 'p-5',
      name: 'Nina',
      breed: 'Spitz Alemão',
      size: 'Pequeno',
    ),
    services: const [ServiceItem(name: 'Tosa', durationMinutes: 90)],
    status: AppointmentStatus.completed,
    tutorName: 'Lucas Martins',
  ),
];
