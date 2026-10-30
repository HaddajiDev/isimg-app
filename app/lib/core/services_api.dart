import '../models/demande.dart';
import '../models/pfe.dart';

/// Administrative services (requests, PFE), kept apart from [ApiClient] so the
/// core client — and every test fake of it — doesn't have to grow with them.
abstract interface class ServicesApi {
  Future<List<DemandeModel>> getDemandeModels();

  Future<List<Demande>> getDemandes();

  Future<List<DemandeMessage>> getDemandeMessages(String demandeId);

  /// Submits a new request built from [model], with [values] keyed by field id.
  Future<void> addDemande(DemandeModel model, Map<String, String> values);

  Future<void> deleteDemande(String demandeId);

  Future<void> addDemandeMessage(String demandeId, String message);

  /// Records that the student opened the request (clears its unread badge).
  Future<void> markDemandeSeen(String demandeId);

  /// Null when the student has no PFE assigned.
  Future<Pfe?> getPfe();
}
