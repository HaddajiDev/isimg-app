import '../models/absences.dart';
import '../models/exam.dart';
import '../models/grade_tree.dart';
import '../models/grades.dart';
import '../models/profile.dart';
import '../models/schedule.dart';
import '../models/seance.dart';

const demoUsername = 'demo';
const demoPassword = 'demo1234';

final _annees = [
  SelectOption(code: '2025/2026', label: '2025/2026', selected: true),
  SelectOption(code: '2024/2025', label: '2024/2025', selected: false),
];

final _sessions = [
  SelectOption(code: 'principale', label: 'Session principale', selected: true),
  SelectOption(code: 'controle', label: 'Session de contrôle', selected: false),
];

Grades demoGrades({String? au, String? ss}) {
  return Grades(
    nom: 'Étudiant Démo',
    cin: '00000000',
    filiere: 'Licence Appliquée en Informatique',
    niveau: 'L3',
    moyenneGenerale: '14.25',
    credits: '30',
    rang: '5/42',
    currentAu: au ?? '2025/2026',
    currentSs: ss ?? 'principale',
    annees: _annees,
    sessions: _sessions,
    semesters: [
      Semestre(
        label: 'Semestre 1',
        unites: [
          Unite(
            libelle: 'Unité Fondamentale 1',
            coefficient: 3,
            credits: 6,
            moyenne: 15.4,
            matieres: [
              Matiere(
                libelle: 'Développement Web Avancé',
                regime: 'Mixte',
                coefficient: 2,
                credits: 4,
                moyenne: 16.2,
                epreuves: [
                  Epreuve(libelle: 'DS (0.4)', poids: 0.4, note: 15),
                  Epreuve(libelle: 'Examen (0.6)', poids: 0.6, note: 17),
                ],
              ),
              Matiere(
                libelle: 'Bases de Données Avancées',
                regime: 'Mixte',
                coefficient: 1.5,
                credits: 2,
                moyenne: 13.8,
                epreuves: [
                  Epreuve(libelle: 'DS (0.4)', poids: 0.4, note: 12),
                  Epreuve(libelle: 'Examen (0.6)', poids: 0.6, note: 15),
                ],
              ),
            ],
          ),
          Unite(
            libelle: 'Unité Transversale 1',
            coefficient: 1,
            credits: 3,
            moyenne: 12.5,
            matieres: [
              Matiere(
                libelle: 'Anglais',
                regime: 'Continu',
                coefficient: 1,
                credits: 3,
                moyenne: 12.5,
                epreuves: [
                  Epreuve(libelle: 'DS (0.3)', poids: 0.3, note: 11),
                  Epreuve(libelle: 'Examen (0.7)', poids: 0.7, note: 13),
                ],
              ),
            ],
          ),
        ],
      ),
      Semestre(
        label: 'Semestre 2',
        unites: [
          Unite(
            libelle: 'Unité Fondamentale 2',
            coefficient: 3,
            credits: 6,
            moyenne: null,
            matieres: [
              Matiere(
                libelle: 'Applications Mobiles',
                regime: 'Mixte',
                coefficient: 2,
                credits: 4,
                moyenne: null,
                epreuves: [
                  Epreuve(libelle: 'DS (0.4)', poids: 0.4, note: 14),
                  Epreuve(libelle: 'Examen (0.6)', poids: 0.6, note: null),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Profile demoProfile() {
  return Profile(
    prenom: 'Étudiant',
    nom: 'Démo',
    cin: '00000000',
    filiere: 'Licence Appliquée en Informatique',
    years: [
      CursusYear(
        annee: '2025/2026',
        niveau: 'L3',
        classe: 'L3-INFO-A',
        groupe: 'G1',
        numeroInscription: '00000000',
        statut: 'Inscrit',
        inscription: 'Réinscription',
        moyenne: '0 (S1)',
        credits: '9',
        resultat: 'NC',
      ),
      CursusYear(
        annee: '2024/2025',
        niveau: 'L2',
        classe: 'L2-INFO-B',
        groupe: 'G2',
        numeroInscription: '00000000',
        statut: 'Inscrit',
        inscription: 'Réinscription',
        moyenne: '13.85',
        credits: '60',
        resultat: 'Admis',
      ),
      CursusYear(
        annee: '2023/2024',
        niveau: 'L1',
        classe: 'L1-INFO-A',
        groupe: 'G3',
        numeroInscription: '00000000',
        statut: 'Inscrit',
        inscription: 'Première inscription',
        moyenne: '12.40',
        credits: '60',
        resultat: 'Admis',
      ),
    ],
  );
}

const _s1 = '08:15-09:45';
const _s2 = '09:55-11:25';
const _s3 = '11:30-13:00';
const _s4 = '13:05-14:35';
const _s5 = '14:40-16:10';
const _s6 = '16:15-17:45';

const _demoSeances = <Seance>[

  Seance(weekday: 1, slot: _s2, type: SeanceType.cours, matiere: 'Mathématiques discrètes', enseignant: 'L. Karoui', salle: 'A2'),
  Seance(weekday: 1, slot: _s4, type: SeanceType.tp, matiere: 'Atelier de programmation', enseignant: 'S. Trabelsi', salle: 'Lab04'),
  Seance(weekday: 1, slot: _s6, type: SeanceType.td, matiere: 'Logique et raisonnement', enseignant: 'N. Belhaj', salle: 'A2'),

  Seance(weekday: 2, slot: _s1, type: SeanceType.td, matiere: 'Expression et communication', enseignant: 'R. Slimani', salle: 'S05'),
  Seance(weekday: 2, slot: _s2, type: SeanceType.tp, matiere: 'Architecture des ordinateurs', enseignant: 'Y. Gharbi', salle: 'LabElec'),
  Seance(weekday: 2, slot: _s4, type: SeanceType.tp, matiere: 'Systèmes d\'exploitation', enseignant: 'K. Jaziri', salle: 'Lab04'),
  Seance(weekday: 2, slot: _s5, type: SeanceType.tp, matiere: 'Création multimédia', enseignant: 'S. Ferchichi', salle: 'Lab07'),
  Seance(weekday: 2, slot: _s6, type: SeanceType.tp, matiere: 'Atelier de programmation', enseignant: 'S. Trabelsi', salle: 'Lab07'),

  Seance(weekday: 3, slot: _s1, type: SeanceType.td, matiere: 'Architecture des ordinateurs', enseignant: 'H. Mansouri', salle: 'S09'),
  Seance(weekday: 3, slot: _s2, type: SeanceType.td, matiere: 'Algorithmique et structures de données', enseignant: 'A. Bouaziz', salle: 'S05'),
  Seance(weekday: 3, slot: _s4, type: SeanceType.cours, matiere: 'Création multimédia', enseignant: 'T. Abidi', salle: 'A2'),
  Seance(weekday: 3, slot: _s6, type: SeanceType.cours, matiere: 'Architecture des ordinateurs', enseignant: 'M. Chaabane', salle: 'A2'),

  Seance(weekday: 4, slot: _s1, type: SeanceType.td, matiere: 'Mathématiques discrètes', enseignant: 'L. Karoui', salle: 'A2'),
  Seance(weekday: 4, slot: _s2, type: SeanceType.cours, matiere: 'Algorithmique et structures de données', enseignant: 'B. Nasri', salle: 'A2'),

  Seance(weekday: 5, slot: _s1, type: SeanceType.cours, matiere: 'Logique et raisonnement', enseignant: 'I. Rekik', salle: 'A1'),
  Seance(weekday: 5, slot: _s2, type: SeanceType.cours, matiere: 'Analyse mathématique', enseignant: 'W. Ayari', salle: 'A5'),
  Seance(weekday: 5, slot: _s3, type: SeanceType.cours, matiere: 'Architecture des ordinateurs', enseignant: 'M. Chaabane', salle: 'A2'),
  Seance(weekday: 5, slot: _s4, type: SeanceType.td, matiere: 'Architecture des ordinateurs', enseignant: 'H. Mansouri', salle: 'S02'),
  Seance(weekday: 5, slot: _s5, type: SeanceType.td, matiere: 'Analyse mathématique', enseignant: 'S. Dridi', salle: 'A6'),
  Seance(weekday: 5, slot: _s6, type: SeanceType.cours, matiere: 'Systèmes d\'exploitation', enseignant: 'K. Jaziri', salle: 'A5'),

  Seance(weekday: 6, slot: _s2, type: SeanceType.cours, matiere: 'Systèmes d\'exploitation', enseignant: 'K. Jaziri', salle: 'A5'),
  Seance(weekday: 6, slot: _s3, type: SeanceType.td, matiere: 'Anglais technique', enseignant: 'F. Ouali', salle: 'A5'),
];

Schedule demoSchedule({String? week}) {
  return Schedule(
    weekLabel: _weekLabel(week),
    hasSessions: true,
    sessions: _demoSeances,
  );
}

String _weekLabel(String? week) {
  final monday = DateTime.tryParse(week ?? '') ?? DateTime.now();
  final saturday = monday.add(const Duration(days: 5));
  String fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  return 'Semaine du ${fmt(monday)} au ${fmt(saturday)}';
}

Absences demoAbsences() {
  return const Absences(
    currentSemestre: 1,
    s1: SemestreAbsences(
      semestre: 1,
      tauxGlobal: 3.2,
      nbreGlobal: 2,
      matieres: [
        MatiereAbsence(
          module: 'Algorithmique avancée',
          taux: 8,
          parType: [TypeAbsence(type: 'Cours', nbre: 1), TypeAbsence(type: 'TP', nbre: 1)],
        ),
        MatiereAbsence(module: 'Base de données', taux: 0, parType: [TypeAbsence(type: 'Cours', nbre: 0)]),
        MatiereAbsence(module: 'Réseaux', taux: 0, parType: [TypeAbsence(type: 'Cours', nbre: 0), TypeAbsence(type: 'TP', nbre: 0)]),
        MatiereAbsence(module: 'Anglais', taux: 0, parType: [TypeAbsence(type: 'TD', nbre: 0)]),
      ],
      entries: [
        AbsenceEntry(date: '2026-03-04', seance: '2', type: 'Cours', module: 'Algorithmique avancée', enseignant: 'R. Abbes'),
        AbsenceEntry(date: '2026-03-11', seance: '4', type: 'TP', module: 'Algorithmique avancée', enseignant: 'K. Hmidi'),
      ],
    ),
    s2: SemestreAbsences(
      semestre: 2,
      tauxGlobal: 0,
      nbreGlobal: 0,
      matieres: [
        MatiereAbsence(module: 'Machine Learning', taux: 0, parType: [TypeAbsence(type: 'Cours', nbre: 0)]),
        MatiereAbsence(module: 'Développement mobile', taux: 0, parType: [TypeAbsence(type: 'TP', nbre: 0)]),
      ],
    ),
  );
}

ExamsSchedule demoExams() {
  final now = DateTime.now();
  DateTime at(int addDays, int h, int m) =>
      DateTime(now.year, now.month, now.day).add(Duration(days: addDays, hours: h, minutes: m));
  return ExamsSchedule(
    exams: [
      Exam(
        matiere: 'Framework & technologies big data',
        type: ExamType.ds,
        epreuve: 'DS',
        debut: at(2, 8, 15),
        horaire: '08:15 - 09:45',
        dureeMinutes: 90,
        salle: 'A6',
        enseignant: 'S. Elji',
        eliminatoire: false,
      ),
      Exam(
        matiere: 'Architecture SOA et services web',
        type: ExamType.examen,
        epreuve: 'Ex',
        debut: at(5, 11, 30),
        horaire: '11:30 - 13:00',
        dureeMinutes: 90,
        salle: 'A2',
        enseignant: 'F. Achour',
        eliminatoire: true,
      ),
      Exam(
        matiere: 'Machine Learning',
        type: ExamType.tp,
        epreuve: 'TP',
        debut: at(9, 14, 0),
        horaire: '14:00 - 15:30',
        dureeMinutes: 60,
        salle: 'Lab07',
        enseignant: 'R. Chamsi',
      ),
    ],
  );
}
