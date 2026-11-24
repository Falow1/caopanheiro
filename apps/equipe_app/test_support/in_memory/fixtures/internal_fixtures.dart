import 'package:equipe_app/domain/models.dart';

// Called by each repository at the original eager or lazy initialization point.
PetService createInitialBath() => const PetService(
  id: 's1',
  name: 'Banho',
  description: 'Higienização completa e secagem',
  duration: 60,
  price: 50,
);

PetService createInitialGroom() => const PetService(
  id: 's2',
  name: 'Tosa',
  description: 'Tosa personalizada por raça e porte',
  duration: 90,
  price: 80,
);

PetService createInitialNails() => const PetService(
  id: 's3',
  name: 'Corte de unhas',
  description: 'Corte seguro com acabamento',
  duration: 20,
  price: 20,
);

List<PetService> createInitialServices(
  PetService bath,
  PetService groom,
  PetService nails,
) => [
  bath,
  groom,
  nails,
  const PetService(
    id: 's4',
    name: 'Hidratação',
    description: 'Tratamento para a pelagem',
    duration: 30,
    price: 35,
    active: false,
  ),
];

List<Customer> createInitialCustomers() => [
  Customer(
    id: 'c1',
    name: 'João Silva',
    phone: '(65) 99912-3401',
    email: 'joao@email.com',
    pets: [
      Pet(
        id: 'p1',
        name: 'Thor',
        species: 'Cachorro',
        breed: 'Golden Retriever',
        size: 'Grande',
        birthDate: DateTime(2021, 5, 12),
      ),
      Pet(
        id: 'p2',
        name: 'Bob',
        species: 'Gato',
        breed: 'SRD',
        size: 'Médio',
        birthDate: DateTime(2020, 2, 20),
      ),
    ],
  ),
  Customer(
    id: 'c2',
    name: 'Ana Souza',
    phone: '(65) 99872-1140',
    email: 'ana@email.com',
    pets: [
      Pet(
        id: 'p3',
        name: 'Mel',
        species: 'Cachorro',
        breed: 'Shih-tzu',
        size: 'Pequeno',
        birthDate: DateTime(2022, 9, 3),
        notes: 'Usar shampoo hipoalergênico.',
      ),
    ],
  ),
  Customer(
    id: 'c3',
    name: 'Marina Alves',
    phone: '(65) 99942-1870',
    email: 'marina@email.com',
    pets: [
      Pet(
        id: 'p4',
        name: 'Lola',
        species: 'Cachorro',
        breed: 'Poodle',
        size: 'Pequeno',
        birthDate: DateTime(2019, 7, 18),
      ),
    ],
  ),
];

List<Appointment> createInitialAppointments(
  List<Customer> customers,
  PetService bath,
  PetService groom,
  PetService nails,
) => [
  Appointment(
    id: 'a1',
    customer: customers[0],
    startsAt: DateTime(2026, 9, 18, 8),
    status: AppointmentStatus.confirmed,
    items: [
      AppointmentItem(pet: customers[0].pets[0], services: [bath, groom]),
    ],
    professional: 'Carlos Mendes',
    notes: 'Thor prefere secagem com temperatura baixa.',
  ),
  Appointment(
    id: 'a2',
    customer: customers[1],
    startsAt: DateTime(2026, 9, 18, 10, 30),
    status: AppointmentStatus.petReceived,
    items: [
      AppointmentItem(pet: customers[1].pets[0], services: [bath]),
    ],
    professional: 'Fernanda Lima',
  ),
  Appointment(
    id: 'a3',
    customer: customers[2],
    startsAt: DateTime(2026, 9, 18, 14),
    status: AppointmentStatus.inProgress,
    items: [
      AppointmentItem(pet: customers[2].pets[0], services: [bath, nails]),
    ],
    professional: 'Fernanda Lima',
  ),
  Appointment(
    id: 'a4',
    customer: customers[0],
    startsAt: DateTime(2026, 9, 19, 9),
    status: AppointmentStatus.confirmed,
    items: [
      AppointmentItem(pet: customers[0].pets[1], services: [bath]),
    ],
  ),
];

List<Professional> createInitialProfessionals() => const [
  Professional(
    id: 'pr1',
    name: 'Carlos Mendes',
    specialty: 'Tosador',
    email: 'carlos@empresa.com',
  ),
  Professional(
    id: 'pr2',
    name: 'Fernanda Lima',
    specialty: 'Banhista',
    email: 'fernanda@empresa.com',
  ),
];

List<ScheduleBlock> createInitialBlocks() => [
  ScheduleBlock(
    id: 'b1',
    date: DateTime(2026, 9, 20),
    start: '12:00',
    end: '14:00',
    reason: 'Almoço especial',
  ),
  ScheduleBlock(
    id: 'b2',
    date: DateTime(2026, 9, 25),
    start: '00:00',
    end: '23:59',
    reason: 'Manutenção',
    fullDay: true,
  ),
];
