import 'package:flutter/material.dart';

/// Perfil de acesso do usuário no app.
enum AppRole {
  pending('Aguardando aprovação', Icons.hourglass_empty),
  admin('Secretaria / administração', Icons.admin_panel_settings),
  pastor('Pastor', Icons.menu_book),
  presbitero('Presbítero', Icons.shield),
  liderDiaconia('Diácono · coordena a escala', Icons.assignment_ind),
  diacono('Diácono', Icons.volunteer_activism),
  membro('Membro', Icons.person);

  const AppRole(this.label, this.icon);
  final String label;
  final IconData icon;

  static AppRole parse(String? v) => AppRole.values.firstWhere((r) => r.name == v, orElse: () => AppRole.pending);

  bool get isApproved => this != AppRole.pending;

  /// Conselho e secretaria: cadastro de membros, eventos, programação, avisos e vídeos.
  bool get isLeader => this == admin || this == pastor || this == presbitero;
  bool get canManageMembers => isLeader;
  bool get canManageEvents => isLeader;
  bool get canPublish => isLeader;

  /// Agenda pastoral completa: horários, visitas de todos e anotações pastorais.
  bool get isPastoral => this == admin || this == pastor;

  /// Monta e publica a escala diaconal.
  bool get canManageEscala => this == admin || this == pastor || this == liderDiaconia;
  bool get isDiacono => this == diacono || this == liderDiaconia;

  /// Pedidos de oração reservados (só para o pastor e o conselho).
  bool get seesPrivatePrayers => isLeader;
  bool get canManageUsers => this == admin || this == pastor;
}

/// Situação do membro no rol da igreja.
enum Situacao {
  comungante('Membro comungante'),
  naoComungante('Membro não comungante'),
  congregado('Congregado'),
  visitante('Visitante'),
  transferido('Transferido'),
  inativo('Inativo');

  const Situacao(this.label);
  final String label;

  static Situacao parse(String? v) => Situacao.values.firstWhere((s) => s.name == v, orElse: () => Situacao.visitante);

  bool get isMembro => this == comungante || this == naoComungante;
}

/// Ofício na igreja (aparece em Contatos).
enum Oficio {
  pastor('Pastor', 'Pastores'),
  presbitero('Presbítero', 'Presbíteros'),
  diacono('Diácono', 'Diáconos');

  const Oficio(this.label, this.plural);
  final String label;
  final String plural;

  static Oficio? tryParse(String? v) {
    for (final o in Oficio.values) {
      if (o.name == v) return o;
    }
    return null;
  }
}

/// Funções da escala diaconal em um culto.
enum FuncaoDiaconal {
  recepcao('Recepção e portaria', 2),
  acolhimento('Acolhimento de visitantes', 1),
  ofertorio('Ofertório', 2),
  ceia('Santa Ceia', 0),
  estacionamento('Estacionamento', 1),
  seguranca('Segurança e rondas', 1),
  apoio('Apoio ao culto e ao púlpito', 1);

  const FuncaoDiaconal(this.label, this.defaultCount);
  final String label;

  /// Quantas pessoas por culto, por padrão (Santa Ceia só quando houver).
  final int defaultCount;

  static FuncaoDiaconal? tryParse(String v) {
    for (final f in FuncaoDiaconal.values) {
      if (f.name == v) return f;
    }
    return null;
  }
}
