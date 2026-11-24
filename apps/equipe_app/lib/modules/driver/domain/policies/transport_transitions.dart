import '../models.dart';

TransportStatus? nextTransportStatus(TransportStatus current) =>
    switch (current) {
      TransportStatus.assigned => TransportStatus.goingToOrigin,
      TransportStatus.goingToOrigin => TransportStatus.petCollected,
      TransportStatus.petCollected => TransportStatus.inTransit,
      TransportStatus.inTransit => TransportStatus.delivered,
      TransportStatus.delivered || TransportStatus.cancelled => null,
    };

bool canTransitionTransport(TransportStatus current, TransportStatus next) =>
    nextTransportStatus(current) == next;
