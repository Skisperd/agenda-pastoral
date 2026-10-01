import '../domain/models.dart';
import 'agenda_store.dart';

/// Membros de exemplo. Coordenadas aproximadas de bairros de São Paulo,
/// só para demonstrar a regra de deslocamento.
const demoMembers = [
  Member(
    id: 'm1',
    name: 'Irmão João',
    phone: '(11) 90000-0001',
    neighborhood: 'Santo Amaro · Zona Sul',
    location: GeoPoint(-23.6544, -46.7095),
  ),
  Member(
    id: 'm2',
    name: 'Irmã Maria',
    phone: '(11) 90000-0002',
    neighborhood: 'Santana · Zona Norte',
    location: GeoPoint(-23.5025, -46.6253),
  ),
  Member(
    id: 'm3',
    name: 'Irmão Pedro',
    phone: '(11) 90000-0003',
    neighborhood: 'Campo Belo · Zona Sul',
    location: GeoPoint(-23.6260, -46.6700),
  ),
  Member(
    id: 'm4',
    name: 'Irmã Ana',
    phone: '(11) 90000-0004',
    neighborhood: 'Tatuapé · Zona Leste',
    location: GeoPoint(-23.5400, -46.5760),
  ),
  Member(
    id: 'm5',
    name: 'Irmão Lucas',
    phone: '(11) 90000-0005',
    neighborhood: 'Lapa · Zona Oeste',
    location: GeoPoint(-23.5225, -46.7040),
  ),
  Member(
    id: 'm6',
    name: 'Irmã Rute',
    phone: '(11) 90000-0006',
    neighborhood: 'Sé · Centro',
    location: GeoPoint(-23.5505, -46.6340),
  ),
];

/// Cenário de demonstração relativo a "hoje":
/// - Nesta semana: amanhã e daqui a 3 dias, das 17h às 22h.
/// - Na semana seguinte: daqui a 7 e 9 dias, das 12h às 17h.
/// - O Irmão João (Zona Sul) já marcou amanhã das 17h às 18h.
MemoryAgendaStore demoStore({DateTime Function()? clock}) {
  final now = (clock ?? DateTime.now)();
  DateTime at(int dayOffset, int hour) => DateTime(now.year, now.month, now.day + dayOffset, hour);

  return MemoryAgendaStore(
    clock: clock,
    members: demoMembers,
    windows: [
      AvailabilityWindow(id: 'w1', start: at(1, 17), end: at(1, 22)),
      AvailabilityWindow(id: 'w2', start: at(3, 17), end: at(3, 22)),
      AvailabilityWindow(id: 'w3', start: at(7, 12), end: at(7, 17)),
      AvailabilityWindow(id: 'w4', start: at(9, 12), end: at(9, 17)),
    ],
    visits: [
      Visit(
        id: 'v1',
        member: demoMembers[0],
        start: at(1, 17),
        end: at(1, 18),
        status: VisitStatus.confirmed,
      ),
    ],
  );
}
