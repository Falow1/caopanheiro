import 'package:tutor_app/domain/models/appointment.dart';
import 'package:tutor_app/domain/models/pet.dart';
import 'package:tutor_app/domain/models/service.dart';
import 'package:tutor_app/domain/models/tutor.dart';

// Called by each repository at the original eager or lazy initialization point.
Tutor createInitialTutor() => const Tutor(
  name: 'Marina Alves',
  phone: '(65) 99942-1870',
  email: 'marina@email.com',
);

List<Pet> createInitialPets() => [
  Pet(
    id: 'pet-1',
    name: 'Thor',
    species: 'Cachorro',
    breed: 'Golden Retriever',
    size: 'Grande',
    birthDate: DateTime(2021, 5, 12),
    notes: 'Fica mais tranquilo quando é chamado pelo nome.',
    emoji: '🐕',
  ),
  Pet(
    id: 'pet-2',
    name: 'Mel',
    species: 'Cachorro',
    breed: 'Shih-tzu',
    size: 'Pequeno',
    birthDate: DateTime(2022, 9, 3),
    notes: 'Usar shampoo hipoalergênico.',
    emoji: '🐶',
  ),
  Pet(
    id: 'pet-3',
    name: 'Bob',
    species: 'Gato',
    breed: 'SRD',
    size: 'Médio',
    birthDate: DateTime(2020, 2, 20),
    emoji: '🐈',
  ),
];

List<PetService> createInitialServices() => const [
  PetService(
    id: 'srv-1',
    name: 'Banho',
    description: 'Higienização completa e secagem cuidadosa',
    price: 50,
    durationMinutes: 60,
  ),
  PetService(
    id: 'srv-2',
    name: 'Tosa',
    description: 'Tosa personalizada conforme a raça e o porte',
    price: 80,
    durationMinutes: 90,
  ),
  PetService(
    id: 'srv-3',
    name: 'Corte de unhas',
    description: 'Corte seguro com acabamento',
    price: 20,
    durationMinutes: 20,
  ),
  PetService(
    id: 'srv-4',
    name: 'Hidratação',
    description: 'Tratamento para pelagem macia e saudável',
    price: 35,
    durationMinutes: 30,
  ),
];

List<Appointment> createInitialAppointments() => [
  Appointment(
    id: 'agd-1',
    startsAt: DateTime(2026, 9, 22, 14),
    status: AppointmentStatus.inProgress,
    items: const [
      AppointmentItem(
        petId: 'pet-1',
        petName: 'Thor',
        serviceNames: ['Banho', 'Tosa'],
        price: 130,
        durationMinutes: 150,
      ),
    ],
    history: [
      StatusEvent(
        status: AppointmentStatus.confirmed,
        at: DateTime(2026, 9, 16, 10, 30),
      ),
      StatusEvent(
        status: AppointmentStatus.petReceived,
        at: DateTime(2026, 9, 22, 13, 52),
      ),
      StatusEvent(
        status: AppointmentStatus.inProgress,
        at: DateTime(2026, 9, 22, 14, 8),
      ),
    ],
  ),
  Appointment(
    id: 'agd-2',
    startsAt: DateTime(2026, 9, 28, 10, 30),
    status: AppointmentStatus.confirmed,
    items: const [
      AppointmentItem(
        petId: 'pet-2',
        petName: 'Mel',
        serviceNames: ['Banho', 'Hidratação'],
        price: 85,
        durationMinutes: 90,
      ),
    ],
    history: [
      StatusEvent(
        status: AppointmentStatus.confirmed,
        at: DateTime(2026, 9, 17, 16, 40),
      ),
    ],
  ),
  Appointment(
    id: 'agd-0',
    startsAt: DateTime(2026, 8, 12, 9),
    status: AppointmentStatus.completed,
    items: const [
      AppointmentItem(
        petId: 'pet-3',
        petName: 'Bob',
        serviceNames: ['Banho', 'Corte de unhas'],
        price: 70,
        durationMinutes: 80,
      ),
    ],
    history: [
      StatusEvent(
        status: AppointmentStatus.confirmed,
        at: DateTime(2026, 8, 8, 11),
      ),
      StatusEvent(
        status: AppointmentStatus.petReceived,
        at: DateTime(2026, 8, 12, 8, 55),
      ),
      StatusEvent(
        status: AppointmentStatus.inProgress,
        at: DateTime(2026, 8, 12, 9, 5),
      ),
      StatusEvent(
        status: AppointmentStatus.completed,
        at: DateTime(2026, 8, 12, 10, 22),
      ),
    ],
  ),
];
