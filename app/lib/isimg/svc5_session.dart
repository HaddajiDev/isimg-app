import 'dart:convert';

class Svc5Session {
  final String utoken;
  final String userId;

  final String nce;
  final String classeId;
  final String gid;
  final String sexe;

  final int au;
  final int yearBase;

  final double tauxElimination;

  final List<String> slots;
  final List<String> ramadanSlots;
  final String? ramadanStart;
  final String? ramadanEnd;

  final String? prenom;
  final String? nom;
  final String? cin;
  final String? filiere;
  final String? niveau;

  const Svc5Session({
    required this.utoken,
    required this.userId,
    required this.nce,
    required this.classeId,
    required this.gid,
    required this.sexe,
    required this.au,
    required this.yearBase,
    this.tauxElimination = 20,
    this.slots = const [],
    this.ramadanSlots = const [],
    this.ramadanStart,
    this.ramadanEnd,
    this.prenom,
    this.nom,
    this.cin,
    this.filiere,
    this.niveau,
  });

  Svc5Session copyWith({String? utoken, String? userId}) => Svc5Session(
        utoken: utoken ?? this.utoken,
        userId: userId ?? this.userId,
        nce: nce,
        classeId: classeId,
        gid: gid,
        sexe: sexe,
        au: au,
        yearBase: yearBase,
        tauxElimination: tauxElimination,
        slots: slots,
        ramadanSlots: ramadanSlots,
        ramadanStart: ramadanStart,
        ramadanEnd: ramadanEnd,
        prenom: prenom,
        nom: nom,
        cin: cin,
        filiere: filiere,
        niveau: niveau,
      );

  Map<String, dynamic> toJson() => {
        'v': 5,
        'utoken': utoken,
        'userId': userId,
        'nce': nce,
        'classeId': classeId,
        'gid': gid,
        'sexe': sexe,
        'au': au,
        'yearBase': yearBase,
        'tauxElimination': tauxElimination,
        'slots': slots,
        'ramadanSlots': ramadanSlots,
        'ramadanStart': ramadanStart,
        'ramadanEnd': ramadanEnd,
        'prenom': prenom,
        'nom': nom,
        'cin': cin,
        'filiere': filiere,
        'niveau': niveau,
      };

  String encode() => jsonEncode(toJson());

  static Svc5Session? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic> || json['v'] != 5) return null;
      return Svc5Session(
        utoken: json['utoken'] as String,
        userId: json['userId'] as String,
        nce: json['nce'] as String? ?? '',
        classeId: json['classeId'] as String? ?? '',
        gid: json['gid'] as String? ?? '0',
        sexe: json['sexe'] as String? ?? '0',
        au: (json['au'] as num?)?.toInt() ?? 0,
        yearBase: (json['yearBase'] as num?)?.toInt() ?? 0,
        tauxElimination: (json['tauxElimination'] as num?)?.toDouble() ?? 20,
        slots: (json['slots'] as List<dynamic>? ?? []).cast<String>(),
        ramadanSlots: (json['ramadanSlots'] as List<dynamic>? ?? []).cast<String>(),
        ramadanStart: json['ramadanStart'] as String?,
        ramadanEnd: json['ramadanEnd'] as String?,
        prenom: json['prenom'] as String?,
        nom: json['nom'] as String?,
        cin: json['cin'] as String?,
        filiere: json['filiere'] as String?,
        niveau: json['niveau'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  String labelFor(int auId) {
    final first = yearBase + auId;
    return '$first-${first + 1}';
  }
}
