String? _s(dynamic v) {
  if (v == null) return null;
  final t = v.toString().trim();
  if (t.isEmpty || t == '0' || t == 'null') return null;
  return t;
}

String? _raw(dynamic v) {
  if (v == null) return null;
  final t = v.toString().trim();
  return t.isEmpty ? null : t;
}

class StudentInfo {
  final String? cin;
  final String? nce;
  final String? prenom;
  final String? nom;
  final String? prenomAr;
  final String? nomAr;
  final String? sexe;

  final String? classeName;
  final String? niveau;
  final String? diplome;
  final String? groupe;

  final String? dateNaissance;
  final String? lieuNaissance;
  final String? lieuNaissanceAr;
  final String? nationalite;
  final String? adresse;
  final String? codePostal;
  final String? ville;

  final String? mobile;
  final String? email;

  final String? nomParent;
  final String? mobileParent;

  final String? anneeBac;
  final String? typeBac;
  final String? sessionBac;
  final String? mentionBac;

  const StudentInfo({
    this.cin,
    this.nce,
    this.prenom,
    this.nom,
    this.prenomAr,
    this.nomAr,
    this.sexe,
    this.classeName,
    this.niveau,
    this.diplome,
    this.groupe,
    this.dateNaissance,
    this.lieuNaissance,
    this.lieuNaissanceAr,
    this.nationalite,
    this.adresse,
    this.codePostal,
    this.ville,
    this.mobile,
    this.email,
    this.nomParent,
    this.mobileParent,
    this.anneeBac,
    this.typeBac,
    this.sessionBac,
    this.mentionBac,
  });

  String get fullName => [prenom, nom].whereType<String>().join(' ').trim();

  String get fullNameAr => [nomAr, prenomAr].whereType<String>().join(' ').trim();

  String get initials {
    final parts = [prenom, nom].whereType<String>().where((p) => p.isNotEmpty);
    return parts.map((p) => p[0].toUpperCase()).take(2).join();
  }

  bool get hasBac => anneeBac != null;

  factory StudentInfo.fromJson(Map<String, dynamic> j) => StudentInfo(
        cin: _s(j['cin']),
        nce: _s(j['nce']),
        prenom: _s(j['prenom']),
        nom: _s(j['nom']),
        prenomAr: _raw(j['prenom_ar']),
        nomAr: _raw(j['nom_ar']),
        sexe: _raw(j['sexe']),
        classeName: _s(j['classe_name']),
        niveau: _s(j['niveau']),
        diplome: _s(j['diplome']),
        groupe: _s(j['code']),
        dateNaissance: _s(j['date_naissance']),
        lieuNaissance: _s(j['lieu_naissance']),
        lieuNaissanceAr: _raw(j['lieu_naissance_ar']),
        nationalite: _s(j['nationalite']),
        adresse: _s(j['adresse']),
        codePostal: _s(j['codepostal']),
        ville: _s(j['ville']),
        mobile: _s(j['mobile']),
        email: _s(j['gmail']),
        nomParent: _s(j['nomparent']),
        mobileParent: _s(j['mobileparent']),
        anneeBac: _s(j['annee_bac']),
        typeBac: _s(j['type_bac']),
        sessionBac: _s(j['session_bac']),
        mentionBac: _s(j['mention_bac']),
      );

  Map<String, dynamic> toJson() => {
        'cin': cin,
        'nce': nce,
        'prenom': prenom,
        'nom': nom,
        'prenom_ar': prenomAr,
        'nom_ar': nomAr,
        'sexe': sexe,
        'classe_name': classeName,
        'niveau': niveau,
        'diplome': diplome,
        'code': groupe,
        'date_naissance': dateNaissance,
        'lieu_naissance': lieuNaissance,
        'lieu_naissance_ar': lieuNaissanceAr,
        'nationalite': nationalite,
        'adresse': adresse,
        'codepostal': codePostal,
        'ville': ville,
        'mobile': mobile,
        'gmail': email,
        'nomparent': nomParent,
        'mobileparent': mobileParent,
        'annee_bac': anneeBac,
        'type_bac': typeBac,
        'session_bac': sessionBac,
        'mention_bac': mentionBac,
      };
}
