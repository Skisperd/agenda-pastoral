/// Perfil da conta no app da igreja (users/{uid}.role): o app de mídia usa os
/// mesmos logins e só acrescenta o nível na equipa de mídia.
enum AppRole {
  pending('Aguardando aprovação'),
  admin('Secretaria / administração'),
  pastor('Pastor'),
  presbitero('Presbítero'),
  liderDiaconia('Diácono · coordena a escala'),
  diacono('Diácono'),
  membro('Membro');

  const AppRole(this.label);
  final String label;

  static AppRole parse(String? v) => AppRole.values.firstWhere((r) => r.name == v, orElse: () => AppRole.pending);

  bool get isApproved => this != pending;
  bool get isLeader => this == admin || this == pastor || this == presbitero;
}

/// Lugar na equipa de mídia (users/{uid}.midia), definido no app da igreja.
enum NivelMidia {
  operador('Equipa de mídia'),
  lider('Liderança de mídia');

  const NivelMidia(this.label);
  final String label;

  static NivelMidia? tryParse(String? v) {
    for (final n in NivelMidia.values) {
      if (n.name == v) return n;
    }
    return null;
  }
}
