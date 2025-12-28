// 📊 FINANCIA PRO - Logiciel de Gestion Comptable Complet
// Version 1.0.0 - Application 100% Locale avec Génération PDF

import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const FinanciaProApp());
}

// ====================== CONSTANTES & CONFIGURATION ======================

class AppConfig {
  static const String appName = "Financia Pro";
  static const String version = "1.0.0";
  static const String dbName = "financia_pro.db";
  static const int dbVersion = 1;
  
  // Palettes de couleurs
  static const Color primaryColor = Color(0xFF1E3A8A);
  static const Color secondaryColor = Color(0xFF10B981);
  static const Color accentColor = Color(0xFF8B5CF6);
  static const Color successColor = Color(0xFF22C55E);
  static const Color dangerColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color lightColor = Color(0xFFF8FAFC);
  static const Color darkColor = Color(0xFF1F2937);
  
  // Chemins de stockage
  static late String appDir;
  static late String dbPath;
  static late String pdfDir;
  static late String backupDir;
  
  static Future<void> initPaths() async {
    final directory = await getApplicationDocumentsDirectory();
    appDir = directory.path;
    dbPath = path.join(appDir, dbName);
    pdfDir = path.join(appDir, 'documents', 'pdf');
    backupDir = path.join(appDir, 'backups');
    
    // Création des répertoires
    await Directory(pdfDir).create(recursive: true);
    await Directory(backupDir).create(recursive: true);
    await Directory(path.join(pdfDir, 'factures')).create(recursive: true);
    await Directory(path.join(pdfDir, 'devis')).create(recursive: true);
    await Directory(path.join(pdfDir, 'bilans')).create(recursive: true);
    await Directory(path.join(pdfDir, 'declarations')).create(recursive: true);
  }
}

// ====================== MODÈLES DE DONNÉES ======================

class Client {
  int? id;
  String nom;
  String? siret;
  String? adresse;
  String? email;
  String? telephone;
  double solde;
  DateTime dateCreation;
  String? categorie; // CLIENT ou FOURNISSEUR
  
  Client({
    this.id,
    required this.nom,
    this.siret,
    this.adresse,
    this.email,
    this.telephone,
    this.solde = 0.0,
    DateTime? dateCreation,
    this.categorie = 'CLIENT',
  }) : dateCreation = dateCreation ?? DateTime.now();
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'siret': siret,
      'adresse': adresse,
      'email': email,
      'telephone': telephone,
      'solde': solde,
      'dateCreation': dateCreation.toIso8601String(),
      'categorie': categorie,
    };
  }
  
  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'],
      nom: map['nom'],
      siret: map['siret'],
      adresse: map['adresse'],
      email: map['email'],
      telephone: map['telephone'],
      solde: map['solde'] ?? 0.0,
      dateCreation: DateTime.parse(map['dateCreation']),
      categorie: map['categorie'] ?? 'CLIENT',
    );
  }
}

class LigneFacture {
  int? id;
  int factureId;
  String description;
  double quantite;
  double prixUnitaire;
  double tauxTVA;
  
  LigneFacture({
    this.id,
    required this.factureId,
    required this.description,
    required this.quantite,
    required this.prixUnitaire,
    this.tauxTVA = 20.0,
  });
  
  double get totalHT => quantite * prixUnitaire;
  double get montantTVA => totalHT * (tauxTVA / 100);
  double get totalTTC => totalHT + montantTVA;
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'factureId': factureId,
      'description': description,
      'quantite': quantite,
      'prixUnitaire': prixUnitaire,
      'tauxTVA': tauxTVA,
    };
  }
  
  factory LigneFacture.fromMap(Map<String, dynamic> map) {
    return LigneFacture(
      id: map['id'],
      factureId: map['factureId'],
      description: map['description'],
      quantite: map['quantite'] ?? 0.0,
      prixUnitaire: map['prixUnitaire'] ?? 0.0,
      tauxTVA: map['tauxTVA'] ?? 20.0,
    );
  }
}

class Facture {
  int? id;
  String numero;
  int clientId;
  DateTime dateEmission;
  DateTime dateEcheance;
  double tva;
  String statut; // BROUILLON, VALIDEE, ENVOYEE, PAYEE, IMPAYEE
  String type; // VENTE, ACHAT
  String? pdfPath;
  String? notes;
  
  List<LigneFacture> lignes = [];
  Client? client;
  
  Facture({
    this.id,
    required this.numero,
    required this.clientId,
    required this.dateEmission,
    required this.dateEcheance,
    this.tva = 20.0,
    this.statut = 'BROUILLON',
    this.type = 'VENTE',
    this.pdfPath,
    this.notes,
  });
  
  double get totalHT {
    return lignes.fold(0.0, (sum, ligne) => sum + ligne.totalHT);
  }
  
  double get montantTVA {
    return lignes.fold(0.0, (sum, ligne) => sum + ligne.montantTVA);
  }
  
  double get totalTTC {
    return lignes.fold(0.0, (sum, ligne) => sum + ligne.totalTTC);
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numero': numero,
      'clientId': clientId,
      'dateEmission': dateEmission.toIso8601String(),
      'dateEcheance': dateEcheance.toIso8601String(),
      'tva': tva,
      'statut': statut,
      'type': type,
      'pdfPath': pdfPath,
      'notes': notes,
    };
  }
  
  factory Facture.fromMap(Map<String, dynamic> map) {
    return Facture(
      id: map['id'],
      numero: map['numero'],
      clientId: map['clientId'],
      dateEmission: DateTime.parse(map['dateEmission']),
      dateEcheance: DateTime.parse(map['dateEcheance']),
      tva: map['tva'] ?? 20.0,
      statut: map['statut'] ?? 'BROUILLON',
      type: map['type'] ?? 'VENTE',
      pdfPath: map['pdfPath'],
      notes: map['notes'],
    );
  }
}

class CompteComptable {
  int? id;
  String numero;
  String libelle;
  String type; // ACTIF, PASSIF, PRODUITS, CHARGES
  double soldeInitial;
  
  CompteComptable({
    this.id,
    required this.numero,
    required this.libelle,
    required this.type,
    this.soldeInitial = 0.0,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numero': numero,
      'libelle': libelle,
      'type': type,
      'soldeInitial': soldeInitial,
    };
  }
  
  factory CompteComptable.fromMap(Map<String, dynamic> map) {
    return CompteComptable(
      id: map['id'],
      numero: map['numero'],
      libelle: map['libelle'],
      type: map['type'],
      soldeInitial: map['soldeInitial'] ?? 0.0,
    );
  }
}

class EcritureComptable {
  int? id;
  DateTime date;
  String libelle;
  int compteDebitId;
  int compteCreditId;
  double montant;
  String journal; // VENTES, ACHATS, BANQUE, CAISSE
  String? pieceJustificative;
  
  CompteComptable? compteDebit;
  CompteComptable? compteCredit;
  
  EcritureComptable({
    this.id,
    required this.date,
    required this.libelle,
    required this.compteDebitId,
    required this.compteCreditId,
    required this.montant,
    this.journal = 'DIVERS',
    this.pieceJustificative,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'libelle': libelle,
      'compteDebitId': compteDebitId,
      'compteCreditId': compteCreditId,
      'montant': montant,
      'journal': journal,
      'pieceJustificative': pieceJustificative,
    };
  }
  
  factory EcritureComptable.fromMap(Map<String, dynamic> map) {
    return EcritureComptable(
      id: map['id'],
      date: DateTime.parse(map['date']),
      libelle: map['libelle'],
      compteDebitId: map['compteDebitId'],
      compteCreditId: map['compteCreditId'],
      montant: map['montant'] ?? 0.0,
      journal: map['journal'] ?? 'DIVERS',
      pieceJustificative: map['pieceJustificative'],
    );
  }
}

class DeclarationTVA {
  int? id;
  int trimestre;
  int annee;
  DateTime dateDeclaration;
  double tvaCollectee;
  double tvaDeductible;
  String statut; // BROUILLON, VALIDEE, ENVOYEE, PAYEE
  String? pdfPath;
  
  DeclarationTVA({
    this.id,
    required this.trimestre,
    required this.annee,
    required this.dateDeclaration,
    this.tvaCollectee = 0.0,
    this.tvaDeductible = 0.0,
    this.statut = 'BROUILLON',
    this.pdfPath,
  });
  
  double get tvaAPayer => tvaCollectee - tvaDeductible;
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trimestre': trimestre,
      'annee': annee,
      'dateDeclaration': dateDeclaration.toIso8601String(),
      'tvaCollectee': tvaCollectee,
      'tvaDeductible': tvaDeductible,
      'statut': statut,
      'pdfPath': pdfPath,
    };
  }
  
  factory DeclarationTVA.fromMap(Map<String, dynamic> map) {
    return DeclarationTVA(
      id: map['id'],
      trimestre: map['trimestre'],
      annee: map['annee'],
      dateDeclaration: DateTime.parse(map['dateDeclaration']),
      tvaCollectee: map['tvaCollectee'] ?? 0.0,
      tvaDeductible: map['tvaDeductible'] ?? 0.0,
      statut: map['statut'] ?? 'BROUILLON',
      pdfPath: map['pdfPath'],
    );
  }
}

// ====================== BASE DE DONNÉES ======================

class DatabaseManager {
  static final DatabaseManager _instance = DatabaseManager._internal();
  factory DatabaseManager() => _instance;
  DatabaseManager._internal();
  
  File? _dbFile;
  Map<String, dynamic> _dbData = {
    'clients': [],
    'factures': [],
    'lignes_factures': [],
    'comptes': [],
    'ecritures': [],
    'declarations_tva': [],
    'parametres': [],
  };
  
  Future<void> init() async {
    await AppConfig.initPaths();
    _dbFile = File(AppConfig.dbPath);
    
    if (await _dbFile!.exists()) {
      final content = await _dbFile!.readAsString();
      _dbData = json.decode(content);
    } else {
      await _createInitialData();
      await _save();
    }
  }
  
  Future<void> _createInitialData() async {
    // Comptes comptables initiaux
    final comptesInitiaux = [
      CompteComptable(numero: '512', libelle: 'Banque', type: 'ACTIF'),
      CompteComptable(numero: '53', libelle: 'Caisse', type: 'ACTIF'),
      CompteComptable(numero: '411', libelle: 'Clients', type: 'ACTIF'),
      CompteComptable(numero: '401', libelle: 'Fournisseurs', type: 'PASSIF'),
      CompteComptable(numero: '44571', libelle: 'TVA Collectée', type: 'PASSIF'),
      CompteComptable(numero: '44566', libelle: 'TVA Déductible', type: 'ACTIF'),
      CompteComptable(numero: '706', libelle: 'Ventes de produits', type: 'PRODUITS'),
      CompteComptable(numero: '607', libelle: 'Achats de marchandises', type: 'CHARGES'),
    ];
    
    for (var compte in comptesInitiaux) {
      await insertCompte(compte);
    }
    
    // Paramètres initiaux
    _dbData['parametres'] = [
      {'key': 'nom_entreprise', 'value': 'Mon Entreprise'},
      {'key': 'adresse_entreprise', 'value': '123 Rue de Paris, 75000 Paris'},
      {'key': 'siret_entreprise', 'value': '123 456 789 00012'},
      {'key': 'tva_intracom', 'value': 'FR123456789'},
      {'key': 'prochain_num_facture', 'value': '1'},
      {'key': 'prochain_num_devis', 'value': '1'},
      {'key': 'taux_tva_defaut', 'value': '20.0'},
    ];
  }
  
  Future<void> _save() async {
    await _dbFile!.writeAsString(json.encode(_dbData));
  }
  
  // CRUD Clients
  Future<int> insertClient(Client client) async {
    final maxId = _dbData['clients'].fold<int>(0, (max, item) {
      final id = item['id'] as int? ?? 0;
      return id > max ? id : max;
    });
    
    client.id = maxId + 1;
    _dbData['clients'].add(client.toMap());
    await _save();
    return client.id!;
  }
  
  Future<List<Client>> getClients() async {
    return _dbData['clients'].map<Client>((map) => Client.fromMap(map)).toList();
  }
  
  Future<Client?> getClient(int id) async {
    final map = _dbData['clients'].firstWhere(
      (item) => item['id'] == id,
      orElse: () => null,
    );
    return map != null ? Client.fromMap(map) : null;
  }
  
  Future<void> updateClient(Client client) async {
    final index = _dbData['clients'].indexWhere((item) => item['id'] == client.id);
    if (index != -1) {
      _dbData['clients'][index] = client.toMap();
      await _save();
    }
  }
  
  Future<void> deleteClient(int id) async {
    _dbData['clients'].removeWhere((item) => item['id'] == id);
    await _save();
  }
  
  // CRUD Factures
  Future<int> insertFacture(Facture facture) async {
    final maxId = _dbData['factures'].fold<int>(0, (max, item) {
      final id = item['id'] as int? ?? 0;
      return id > max ? id : max;
    });
    
    facture.id = maxId + 1;
    _dbData['factures'].add(facture.toMap());
    
    // Mettre à jour le numéro de facture
    if (facture.type == 'VENTE') {
      final paramIndex = _dbData['parametres'].indexWhere(
        (p) => p['key'] == 'prochain_num_facture'
      );
      if (paramIndex != -1) {
        final current = int.parse(_dbData['parametres'][paramIndex]['value']);
        _dbData['parametres'][paramIndex]['value'] = (current + 1).toString();
      }
    }
    
    await _save();
    return facture.id!;
  }
  
  Future<List<Facture>> getFactures() async {
    final factures = _dbData['factures'].map<Facture>((map) => Facture.fromMap(map)).toList();
    
    // Charger les lignes pour chaque facture
    for (var facture in factures) {
      facture.lignes = await getLignesFacture(facture.id!);
      facture.client = await getClient(facture.clientId);
    }
    
    return factures;
  }
  
  Future<void> updateFacture(Facture facture) async {
    final index = _dbData['factures'].indexWhere((item) => item['id'] == facture.id);
    if (index != -1) {
      _dbData['factures'][index] = facture.toMap();
      await _save();
    }
  }
  
  // CRUD Lignes Facture
  Future<int> insertLigneFacture(LigneFacture ligne) async {
    final maxId = _dbData['lignes_factures'].fold<int>(0, (max, item) {
      final id = item['id'] as int? ?? 0;
      return id > max ? id : max;
    });
    
    ligne.id = maxId + 1;
    _dbData['lignes_factures'].add(ligne.toMap());
    await _save();
    return ligne.id!;
  }
  
  Future<List<LigneFacture>> getLignesFacture(int factureId) async {
    final lignes = _dbData['lignes_factures']
        .where((item) => item['factureId'] == factureId)
        .map<LigneFacture>((map) => LigneFacture.fromMap(map))
        .toList();
    
    return lignes;
  }
  
  // CRUD Comptes Comptables
  Future<int> insertCompte(CompteComptable compte) async {
    final maxId = _dbData['comptes'].fold<int>(0, (max, item) {
      final id = item['id'] as int? ?? 0;
      return id > max ? id : max;
    });
    
    compte.id = maxId + 1;
    _dbData['comptes'].add(compte.toMap());
    await _save();
    return compte.id!;
  }
  
  Future<List<CompteComptable>> getComptes() async {
    return _dbData['comptes'].map<CompteComptable>((map) => CompteComptable.fromMap(map)).toList();
  }
  
  // CRUD Écritures Comptables
  Future<int> insertEcriture(EcritureComptable ecriture) async {
    final maxId = _dbData['ecritures'].fold<int>(0, (max, item) {
      final id = item['id'] as int? ?? 0;
      return id > max ? id : max;
    });
    
    ecriture.id = maxId + 1;
    _dbData['ecritures'].add(ecriture.toMap());
    await _save();
    return ecriture.id!;
  }
  
  Future<List<EcritureComptable>> getEcritures() async {
    final ecritures = _dbData['ecritures']
        .map<EcritureComptable>((map) => EcritureComptable.fromMap(map))
        .toList();
    
    // Charger les comptes associés
    for (var ecriture in ecritures) {
      ecriture.compteDebit = await getCompteById(ecriture.compteDebitId);
      ecriture.compteCredit = await getCompteById(ecriture.compteCreditId);
    }
    
    return ecritures;
  }
  
  Future<CompteComptable?> getCompteById(int id) async {
    final map = _dbData['comptes'].firstWhere(
      (item) => item['id'] == id,
      orElse: () => null,
    );
    return map != null ? CompteComptable.fromMap(map) : null;
  }
  
  // CRUD Déclarations TVA
  Future<int> insertDeclarationTVA(DeclarationTVA declaration) async {
    final maxId = _dbData['declarations_tva'].fold<int>(0, (max, item) {
      final id = item['id'] as int? ?? 0;
      return id > max ? id : max;
    });
    
    declaration.id = maxId + 1;
    _dbData['declarations_tva'].add(declaration.toMap());
    await _save();
    return declaration.id!;
  }
  
  // Paramètres
  Future<String?> getParametre(String key) async {
    final param = _dbData['parametres'].firstWhere(
      (item) => item['key'] == key,
      orElse: () => null,
    );
    return param?['value'];
  }
  
  Future<void> setParametre(String key, String value) async {
    final index = _dbData['parametres'].indexWhere((item) => item['key'] == key);
    if (index != -1) {
      _dbData['parametres'][index]['value'] = value;
    } else {
      _dbData['parametres'].add({'key': key, 'value': value});
    }
    await _save();
  }
  
  // Sauvegarde/Restauration
  Future<File> creerSauvegarde() async {
    final now = DateTime.now();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(now);
    final backupFile = File(path.join(AppConfig.backupDir, 'backup_$timestamp.json'));
    
    await backupFile.writeAsString(json.encode(_dbData));
    return backupFile;
  }
  
  Future<void> restaurerSauvegarde(File backupFile) async {
    final content = await backupFile.readAsString();
    _dbData = json.decode(content);
    await _save();
  }
}

// ====================== GESTIONNAIRE PDF ======================

class PDFManager {
  static final PDFManager _instance = PDFManager._internal();
  factory PDFManager() => _instance;
  PDFManager._internal();
  
  Future<File> genererFacturePDF(Facture facture) async {
    final pdf = pw.Document();
    final client = facture.client;
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // En-tête
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('FINANCIA PRO',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          )),
                      pw.Text('Logiciel de Gestion Comptable'),
                      pw.Text('Version ${AppConfig.version}'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('FACTURE',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                          )),
                      pw.Text(facture.numero),
                      pw.Text('Date: ${DateFormat('dd/MM/yyyy').format(facture.dateEmission)}'),
                    ],
                  ),
                ],
              ),
              
              pw.SizedBox(height: 30),
              
              // Coordonnées client
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Facturé à:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    if (client != null) ...[
                      pw.Text(client.nom),
                      if (client.adresse != null && client.adresse!.isNotEmpty)
                        pw.Text(client.adresse!),
                      if (client.siret != null && client.siret!.isNotEmpty)
                        pw.Text('SIRET: ${client.siret}'),
                    ],
                  ],
                ),
              ),
              
              pw.SizedBox(height: 30),
              
              // Tableau des lignes
              pw.TableHelper.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headers: ['Description', 'Qté', 'PU HT', 'TVA', 'Total HT'],
                data: facture.lignes.map((ligne) {
                  return [
                    ligne.description,
                    ligne.quantite.toStringAsFixed(2),
                    '${ligne.prixUnitaire.toStringAsFixed(2)} €',
                    '${ligne.tauxTVA}%',
                    '${ligne.totalHT.toStringAsFixed(2)} €',
                  ];
                }).toList(),
                cellAlignment: pw.Alignment.centerRight,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                },
              ),
              
              pw.SizedBox(height: 30),
              
              // Totaux
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text('Total HT: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('${facture.totalHT.toStringAsFixed(2)} €'),
                      ],
                    ),
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text('TVA: '),
                        pw.Text('${facture.montantTVA.toStringAsFixed(2)} €'),
                      ],
                    ),
                    pw.Divider(),
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text('Total TTC: ',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            )),
                        pw.Text('${facture.totalTTC.toStringAsFixed(2)} €',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            )),
                      ],
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 50),
              
              // Mentions légales
              pw.Container(
                child: pw.Text(
                  'En cas de retard de paiement, indemnité forfaitaire pour frais de recouvrement de 40€',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          );
        },
      ),
    );
    
    final pdfBytes = await pdf.save();
    final fileName = 'facture_${facture.numero}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final filePath = path.join(AppConfig.pdfDir, 'factures', fileName);
    
    await Directory(path.dirname(filePath)).create(recursive: true);
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);
    
    // Mettre à jour le chemin dans la facture
    facture.pdfPath = filePath;
    await DatabaseManager().updateFacture(facture);
    
    return file;
  }
  
  Future<File> genererBilanPDF(List<CompteComptable> comptes) async {
    final pdf = pw.Document();
    
    final comptesActifs = comptes.where((c) => c.type == 'ACTIF').toList();
    final comptesPassifs = comptes.where((c) => c.type == 'PASSIF').toList();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('BILAN COMPTABLE',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            ),
            
            pw.SizedBox(height: 20),
            
            // Actif
            pw.Text('ACTIF', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.TableHelper.fromTextArray(
              headers: ['Compte', 'Libellé', 'Solde'],
              data: comptesActifs.map((compte) {
                return [
                  compte.numero,
                  compte.libelle,
                  '${compte.soldeInitial.toStringAsFixed(2)} €',
                ];
              }).toList(),
            ),
            
            pw.SizedBox(height: 30),
            
            // Passif
            pw.Text('PASSIF', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.TableHelper.fromTextArray(
              headers: ['Compte', 'Libellé', 'Solde'],
              data: comptesPassifs.map((compte) {
                return [
                  compte.numero,
                  compte.libelle,
                  '${compte.soldeInitial.toStringAsFixed(2)} €',
                ];
              }).toList(),
            ),
            
            pw.SizedBox(height: 30),
            
            // Totaux
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Actif:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  '${_calculerTotal(comptesActifs).toStringAsFixed(2)} €',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Passif:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  '${_calculerTotal(comptesPassifs).toStringAsFixed(2)} €',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ];
        },
      ),
    );
    
    final fileName = 'bilan_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final filePath = path.join(AppConfig.pdfDir, 'bilans', fileName);
    
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    
    return file;
  }
  
  double _calculerTotal(List<CompteComptable> comptes) {
    return comptes.fold(0.0, (sum, compte) => sum + compte.soldeInitial);
  }
}

// ====================== WIDGETS RÉUTILISABLES ======================

class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double? percentChange;
  
  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.percentChange,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                if (percentChange != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: percentChange! > 0
                          ? AppConfig.successColor.withOpacity(0.1)
                          : AppConfig.dangerColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${percentChange! > 0 ? '+' : ''}${percentChange!.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: percentChange! > 0
                            ? AppConfig.successColor
                            : AppConfig.dangerColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppConfig.darkColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FactureCard extends StatelessWidget {
  final Facture facture;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  
  const FactureCard({
    super.key,
    required this.facture,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'PAYEE':
        return AppConfig.successColor;
      case 'ENVOYEE':
        return AppConfig.warningColor;
      case 'IMPAYEE':
        return AppConfig.dangerColor;
      default:
        return Colors.grey;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    facture.numero,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(facture.statut).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      facture.statut,
                      style: TextStyle(
                        color: _getStatusColor(facture.statut),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (facture.client != null)
                Text(
                  facture.client!.nom,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('dd/MM/yyyy').format(facture.dateEmission),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Text(
                    '${facture.totalTTC.toStringAsFixed(2)} €',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (onEdit != null)
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: onEdit,
                      color: AppConfig.primaryColor,
                    ),
                  if (facture.pdfPath != null)
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, size: 20),
                      onPressed: () async {
                        if (facture.pdfPath != null) {
                          await OpenFile.open(facture.pdfPath!);
                        }
                      },
                      color: AppConfig.dangerColor,
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: onDelete,
                      color: AppConfig.dangerColor,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================== ÉCRANS PRINCIPAUX ======================

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  
  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final DatabaseManager _db = DatabaseManager();
  List<Facture> _factures = [];
  List<Client> _clients = [];
  double _totalCA = 0.0;
  double _tresorerie = 0.0;
  int _facturesImpayees = 0;
  
  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }
  
  Future<void> _chargerDonnees() async {
    final factures = await _db.getFactures();
    final clients = await _db.getClients();
    
    setState(() {
      _factures = factures;
      _clients = clients;
      _totalCA = factures
          .where((f) => f.type == 'VENTE' && f.statut == 'PAYEE')
          .fold(0.0, (sum, f) => sum + f.totalTTC);
      _tresorerie = clients.fold(0.0, (sum, c) => sum + c.solde);
      _facturesImpayees = factures.where((f) => f.statut == 'IMPAYEE').length;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de Bord'),
        backgroundColor: AppConfig.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerDonnees,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ParametresScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // KPI
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                KpiCard(
                  title: 'Chiffre d\'Affaires',
                  value: '${_totalCA.toStringAsFixed(2)} €',
                  icon: Icons.euro,
                  color: AppConfig.successColor,
                  percentChange: 12.5,
                ),
                KpiCard(
                  title: 'Trésorerie',
                  value: '${_tresorerie.toStringAsFixed(2)} €',
                  icon: Icons.account_balance,
                  color: AppConfig.primaryColor,
                ),
                KpiCard(
                  title: 'Clients',
                  value: _clients.length.toString(),
                  icon: Icons.people,
                  color: AppConfig.accentColor,
                ),
                KpiCard(
                  title: 'Factures impayées',
                  value: _facturesImpayees.toString(),
                  icon: Icons.warning,
                  color: AppConfig.dangerColor,
                  percentChange: -5.0,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Actions rapides
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Actions Rapides',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildActionButton(
                          icon: Icons.add,
                          label: 'Nouvelle Facture',
                          color: AppConfig.primaryColor,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CreationFactureScreen(),
                              ),
                            );
                          },
                        ),
                        _buildActionButton(
                          icon: Icons.person_add,
                          label: 'Nouveau Client',
                          color: AppConfig.successColor,
                          onPressed: () {
                            _showAjoutClientDialog();
                          },
                        ),
                        _buildActionButton(
                          icon: Icons.picture_as_pdf,
                          label: 'Générer Bilan',
                          color: AppConfig.warningColor,
                          onPressed: () async {
                            final comptes = await _db.getComptes();
                            final pdfFile = await PDFManager().genererBilanPDF(comptes);
                            await OpenFile.open(pdfFile.path);
                          },
                        ),
                        _buildActionButton(
                          icon: Icons.backup,
                          label: 'Sauvegarde',
                          color: AppConfig.accentColor,
                          onPressed: () async {
                            final backupFile = await _db.creerSauvegarde();
                            final scaffoldContext = context;
                            if (scaffoldContext.mounted) {
                              ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                                SnackBar(
                                  content: Text('Sauvegarde créée: ${backupFile.path}'),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Dernières factures
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dernières Factures',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_factures.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Aucune facture pour le moment',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ..._factures.take(5).map((facture) {
                        return FactureCard(
                          facture: facture,
                          onTap: () {
                            _showDetailFacture(facture);
                          },
                          onEdit: () {
                            // TODO: Implémenter l'édition
                          },
                          onDelete: () {
                            // TODO: Implémenter la suppression
                          },
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 120,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        ),
      ),
    );
  }
  
  void _showAjoutClientDialog() {
    final nomController = TextEditingController();
    final siretController = TextEditingController();
    final adresseController = TextEditingController();
    final emailController = TextEditingController();
    final telephoneController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Nouveau Client'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: siretController,
                  decoration: const InputDecoration(
                    labelText: 'SIRET',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: adresseController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: telephoneController,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nomController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Le nom est obligatoire')),
                  );
                  return;
                }
                
                final client = Client(
                  nom: nomController.text,
                  siret: siretController.text.isEmpty ? null : siretController.text,
                  adresse: adresseController.text.isEmpty ? null : adresseController.text,
                  email: emailController.text.isEmpty ? null : emailController.text,
                  telephone: telephoneController.text.isEmpty ? null : telephoneController.text,
                );
                
                await _db.insertClient(client);
                await _chargerDonnees();
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Client ajouté avec succès')),
                  );
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        );
      },
    );
  }
  
  void _showDetailFacture(Facture facture) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      facture.numero,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (facture.client != null)
                  Text('Client: ${facture.client!.nom}'),
                Text('Date: ${DateFormat('dd/MM/yyyy').format(facture.dateEmission)}'),
                Text('Échéance: ${DateFormat('dd/MM/yyyy').format(facture.dateEcheance)}'),
                Text('Statut: ${facture.statut}'),
                
                const SizedBox(height: 24),
                const Text(
                  'Lignes de facture:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final ligne in facture.lignes)
                  ListTile(
                    title: Text(ligne.description),
                    subtitle: Text('${ligne.quantite} x ${ligne.prixUnitaire} €'),
                    trailing: Text('${ligne.totalTTC.toStringAsFixed(2)} €'),
                  ),
                
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total HT:'),
                    Text('${facture.totalHT.toStringAsFixed(2)} €'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TVA:'),
                    Text('${facture.montantTVA.toStringAsFixed(2)} €'),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total TTC:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${facture.totalTTC.toStringAsFixed(2)} €',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final pdfFile = await PDFManager().genererFacturePDF(facture);
                          await OpenFile.open(pdfFile.path);
                        },
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Générer PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.dangerColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Implémenter le marquage comme payée
                        },
                        icon: const Icon(Icons.payment),
                        label: const Text('Marquer Payée'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.successColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});
  
  @override
  ClientsScreenState createState() => ClientsScreenState();
}

class ClientsScreenState extends State<ClientsScreen> {
  final DatabaseManager _db = DatabaseManager();
  List<Client> _clients = [];
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _chargerClients();
  }
  
  Future<void> _chargerClients() async {
    final clients = await _db.getClients();
    setState(() {
      _clients = clients;
    });
  }
  
  List<Client> get _filteredClients {
    if (_searchQuery.isEmpty) return _clients;
    return _clients.where((client) {
      return client.nom.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (client.email?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (client.telephone?.contains(_searchQuery) ?? false);
    }).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        backgroundColor: AppConfig.primaryColor,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              decoration: InputDecoration(
                hintText: 'Rechercher un client...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredClients.length,
              itemBuilder: (context, index) {
                final client = _filteredClients[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppConfig.primaryColor.withOpacity(0.1),
                      child: Text(
                        client.nom.substring(0, 2).toUpperCase(),
                        style: TextStyle(
                          color: AppConfig.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      client.nom,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (client.email != null) Text(client.email!),
                        if (client.telephone != null) Text(client.telephone!),
                        const SizedBox(height: 4),
                        Text(
                          'Solde: ${client.solde.toStringAsFixed(2)} €',
                          style: TextStyle(
                            color: client.solde >= 0
                                ? AppConfig.successColor
                                : AppConfig.dangerColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Modifier'),
                        ),
                        const PopupMenuItem(
                          value: 'factures',
                          child: Text('Voir les factures'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Supprimer'),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditClientDialog(client);
                        } else if (value == 'factures') {
                          // TODO: Voir les factures du client
                        } else if (value == 'delete') {
                          _showDeleteClientDialog(client);
                        }
                      },
                    ),
                    onTap: () {
                      _showEditClientDialog(client);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              final nomController = TextEditingController();
              final siretController = TextEditingController();
              final adresseController = TextEditingController();
              final emailController = TextEditingController();
              final telephoneController = TextEditingController();
              
              return AlertDialog(
                title: const Text('Nouveau Client'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nomController,
                        decoration: const InputDecoration(
                          labelText: 'Nom *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: siretController,
                        decoration: const InputDecoration(
                          labelText: 'SIRET',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: adresseController,
                        decoration: const InputDecoration(
                          labelText: 'Adresse',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: telephoneController,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (nomController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Le nom est obligatoire')),
                        );
                        return;
                      }
                      
                      final client = Client(
                        nom: nomController.text,
                        siret: siretController.text.isEmpty ? null : siretController.text,
                        adresse: adresseController.text.isEmpty ? null : adresseController.text,
                        email: emailController.text.isEmpty ? null : emailController.text,
                        telephone: telephoneController.text.isEmpty ? null : telephoneController.text,
                      );
                      
                      await _db.insertClient(client);
                      await _chargerClients();
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Client ajouté avec succès')),
                        );
                      }
                    },
                    child: const Text('Ajouter'),
                  ),
                ],
              );
            },
          );
        },
        backgroundColor: AppConfig.primaryColor,
        child: const Icon(Icons.person_add),
      ),
    );
  }
  
  void _showEditClientDialog(Client client) {
    final nomController = TextEditingController(text: client.nom);
    final siretController = TextEditingController(text: client.siret ?? '');
    final adresseController = TextEditingController(text: client.adresse ?? '');
    final emailController = TextEditingController(text: client.email ?? '');
    final telephoneController = TextEditingController(text: client.telephone ?? '');
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Modifier Client'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: siretController,
                  decoration: const InputDecoration(
                    labelText: 'SIRET',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: adresseController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: telephoneController,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nomController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Le nom est obligatoire')),
                  );
                  return;
                }
                
                final updatedClient = Client(
                  id: client.id,
                  nom: nomController.text,
                  siret: siretController.text.isEmpty ? null : siretController.text,
                  adresse: adresseController.text.isEmpty ? null : adresseController.text,
                  email: emailController.text.isEmpty ? null : emailController.text,
                  telephone: telephoneController.text.isEmpty ? null : telephoneController.text,
                  solde: client.solde,
                  dateCreation: client.dateCreation,
                  categorie: client.categorie,
                );
                
                await _db.updateClient(updatedClient);
                await _chargerClients();
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Client modifié avec succès')),
                  );
                }
              },
              child: const Text('Sauvegarder'),
            ),
          ],
        );
      },
    );
  }
  
  void _showDeleteClientDialog(Client client) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Supprimer Client'),
          content: Text('Êtes-vous sûr de vouloir supprimer ${client.nom} ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _db.deleteClient(client.id!);
                await _chargerClients();
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Client supprimé avec succès')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.dangerColor,
              ),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }
}

class CreationFactureScreen extends StatefulWidget {
  const CreationFactureScreen({super.key});
  
  @override
  CreationFactureScreenState createState() => CreationFactureScreenState();
}

class CreationFactureScreenState extends State<CreationFactureScreen> {
  final DatabaseManager _db = DatabaseManager();
  final List<LigneFacture> _lignes = [];
  List<Client> _clients = [];
  Client? _selectedClient;
  DateTime _dateEmission = DateTime.now();
  DateTime _dateEcheance = DateTime.now().add(const Duration(days: 30));
  String? _notes;
  
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _quantiteController = TextEditingController(text: '1');
  final TextEditingController _prixController = TextEditingController();
  final TextEditingController _tvaController = TextEditingController(text: '20.0');
  
  @override
  void initState() {
    super.initState();
    _chargerClients();
  }
  
  Future<void> _chargerClients() async {
    final clients = await _db.getClients();
    setState(() {
      _clients = clients;
    });
  }
  
  Future<String> _genererNumeroFacture() async {
    final prochainNum = await _db.getParametre('prochain_num_facture') ?? '1';
    final numero = int.parse(prochainNum);
    final now = DateTime.now();
    final annee = now.year.toString();
    final mois = now.month.toString().padLeft(2, '0');
    final numStr = numero.toString().padLeft(4, '0');
    
    return 'FACT-$annee$mois-$numStr';
  }
  
  void _ajouterLigne() {
    if (_descriptionController.text.isEmpty ||
        _quantiteController.text.isEmpty ||
        _prixController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }
    
    final quantite = double.tryParse(_quantiteController.text) ?? 0;
    final prix = double.tryParse(_prixController.text) ?? 0;
    final tva = double.tryParse(_tvaController.text) ?? 20.0;
    
    if (quantite <= 0 || prix <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantité et prix doivent être positifs')),
      );
      return;
    }
    
    final ligne = LigneFacture(
      factureId: 0, // Temporaire
      description: _descriptionController.text,
      quantite: quantite,
      prixUnitaire: prix,
      tauxTVA: tva,
    );
    
    setState(() {
      _lignes.add(ligne);
    });
    
    // Réinitialiser les champs
    _descriptionController.clear();
    _quantiteController.text = '1';
    _prixController.clear();
    _tvaController.text = '20.0';
    
    // Focus sur la description
    FocusScope.of(context).requestFocus(FocusNode());
  }
  
  void _supprimerLigne(int index) {
    setState(() {
      _lignes.removeAt(index);
    });
  }
  
  double get _totalHT {
    return _lignes.fold(0.0, (sum, ligne) => sum + ligne.totalHT);
  }
  
  double get _totalTVA {
    return _lignes.fold(0.0, (sum, ligne) => sum + ligne.montantTVA);
  }
  
  double get _totalTTC {
    return _lignes.fold(0.0, (sum, ligne) => sum + ligne.totalTTC);
  }
  
  Future<void> _validerFacture() async {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un client')),
      );
      return;
    }
    
    if (_lignes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins une ligne')),
      );
      return;
    }
    
    final numero = await _genererNumeroFacture();
    
    final facture = Facture(
      numero: numero,
      clientId: _selectedClient!.id!,
      dateEmission: _dateEmission,
      dateEcheance: _dateEcheance,
      notes: _notes,
    );
    
    final factureId = await _db.insertFacture(facture);
    
    // Ajouter les lignes
    for (var ligne in _lignes) {
      ligne.factureId = factureId;
      await _db.insertLigneFacture(ligne);
    }
    
    // Générer le PDF
    final factureComplete = Facture(
      id: factureId,
      numero: numero,
      clientId: _selectedClient!.id!,
      dateEmission: _dateEmission,
      dateEcheance: _dateEcheance,
      notes: _notes,
    );
    factureComplete.lignes = _lignes;
    factureComplete.client = _selectedClient;
    
    final pdfFile = await PDFManager().genererFacturePDF(factureComplete);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Facture créée avec succès'),
          action: SnackBarAction(
            label: 'Voir PDF',
            onPressed: () async {
              await OpenFile.open(pdfFile.path);
            },
          ),
        ),
      );
      
      Navigator.pop(context);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle Facture'),
        backgroundColor: AppConfig.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _validerFacture,
            tooltip: 'Valider la facture',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sélection du client
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Client',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Client>(
                      value: _selectedClient,
                      decoration: InputDecoration(
                        labelText: 'Sélectionner un client',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: _clients.map((client) {
                        return DropdownMenuItem<Client>(
                          value: client,
                          child: Text(client.nom),
                        );
                      }).toList(),
                      onChanged: (client) {
                        setState(() {
                          _selectedClient = client;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_selectedClient != null) ...[
                      const Divider(),
                      ListTile(
                        title: Text(_selectedClient!.nom),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_selectedClient!.email != null)
                              Text(_selectedClient!.email!),
                            if (_selectedClient!.telephone != null)
                              Text(_selectedClient!.telephone!),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Dates
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Dates',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Date d\'émission',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            controller: TextEditingController(
                              text: DateFormat('dd/MM/yyyy').format(_dateEmission),
                            ),
                            readOnly: true,
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _dateEmission,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (date != null) {
                                setState(() {
                                  _dateEmission = date;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Date d\'échéance',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            controller: TextEditingController(
                              text: DateFormat('dd/MM/yyyy').format(_dateEcheance),
                            ),
                            readOnly: true,
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _dateEcheance,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (date != null) {
                                setState(() {
                                  _dateEcheance = date;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Ajout de ligne
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Ajouter une ligne',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _quantiteController,
                            decoration: const InputDecoration(
                              labelText: 'Quantité',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _prixController,
                            decoration: const InputDecoration(
                              labelText: 'Prix unitaire HT',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _tvaController,
                            decoration: const InputDecoration(
                              labelText: 'TVA %',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _ajouterLigne,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter la ligne'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConfig.primaryColor,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Lignes ajoutées
            if (_lignes.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lignes de facture',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final entry in _lignes.asMap().entries)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: Colors.grey[50],
                          child: ListTile(
                            title: Text(entry.value.description),
                            subtitle: Text(
                              '${entry.value.quantite} x ${entry.value.prixUnitaire.toStringAsFixed(2)} € (TVA ${entry.value.tauxTVA}%)',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${entry.value.totalTTC.toStringAsFixed(2)} €',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _supprimerLigne(entry.key),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Totaux
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Totaux',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total HT:'),
                        Text(
                          '${_totalHT.toStringAsFixed(2)} €',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total TVA:'),
                        Text(
                          '${_totalTVA.toStringAsFixed(2)} €',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total TTC:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          '${_totalTTC.toStringAsFixed(2)} €',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppConfig.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Notes
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Ajouter des notes ou conditions de paiement...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) {
                        _notes = value;
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class ParametresScreen extends StatefulWidget {
  const ParametresScreen({super.key});
  
  @override
  ParametresScreenState createState() => ParametresScreenState();
}

class ParametresScreenState extends State<ParametresScreen> {
  final DatabaseManager _db = DatabaseManager();
  final Map<String, String> _parametres = {};
  
  @override
  void initState() {
    super.initState();
    _chargerParametres();
  }
  
  Future<void> _chargerParametres() async {
    final keys = [
      'nom_entreprise',
      'adresse_entreprise',
      'siret_entreprise',
      'tva_intracom',
      'taux_tva_defaut',
    ];
    
    for (var key in keys) {
      final value = await _db.getParametre(key);
      if (value != null) {
        _parametres[key] = value;
      }
    }
    
    setState(() {});
  }
  
  Future<void> _sauvegarderParametre(String key, String value) async {
    await _db.setParametre(key, value);
    _parametres[key] = value;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: AppConfig.primaryColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informations de l\'entreprise',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildParametreField(
                    label: 'Nom de l\'entreprise',
                    key: 'nom_entreprise',
                    initialValue: _parametres['nom_entreprise'] ?? '',
                  ),
                  const SizedBox(height: 12),
                  _buildParametreField(
                    label: 'Adresse',
                    key: 'adresse_entreprise',
                    initialValue: _parametres['adresse_entreprise'] ?? '',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  _buildParametreField(
                    label: 'SIRET',
                    key: 'siret_entreprise',
                    initialValue: _parametres['siret_entreprise'] ?? '',
                  ),
                  const SizedBox(height: 12),
                  _buildParametreField(
                    label: 'TVA Intracommunautaire',
                    key: 'tva_intracom',
                    initialValue: _parametres['tva_intracom'] ?? '',
                  ),
                  const SizedBox(height: 12),
                  _buildParametreField(
                    label: 'Taux TVA par défaut (%)',
                    key: 'taux_tva_defaut',
                    initialValue: _parametres['taux_tva_defaut'] ?? '20.0',
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sauvegarde et sécurité',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final backupFile = await _db.creerSauvegarde();
                      final scaffoldContext = context;
                      if (scaffoldContext.mounted) {
                        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                          SnackBar(
                            content: Text('Sauvegarde créée: ${backupFile.path}'),
                            action: SnackBarAction(
                              label: 'Ouvrir',
                              onPressed: () async {
                                await OpenFile.open(backupFile.path);
                              },
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.backup),
                    label: const Text('Créer une sauvegarde'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.successColor,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['json'],
                      );
                      
                      if (result != null && result.files.isNotEmpty) {
                        final file = File(result.files.single.path!);
                        await _db.restaurerSauvegarde(file);
                        
                        final scaffoldContext = context;
                        if (scaffoldContext.mounted) {
                          ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                            const SnackBar(content: Text('Sauvegarde restaurée avec succès')),
                          );
                          await _chargerParametres();
                        }
                      }
                    },
                    icon: const Icon(Icons.restore),
                    label: const Text('Restaurer une sauvegarde'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.warningColor,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'À propos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Icon(Icons.info, color: AppConfig.primaryColor),
                    title: const Text('Version'),
                    subtitle: Text(AppConfig.version),
                  ),
                  ListTile(
                    leading: Icon(Icons.code, color: AppConfig.primaryColor),
                    title: const Text('Développeur'),
                    subtitle: const Text('Financia Pro Team'),
                  ),
                  ListTile(
                    leading: Icon(Icons.email, color: AppConfig.primaryColor),
                    title: const Text('Support'),
                    subtitle: const Text('support@financiapro.com'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildParametreField({
    required String label,
    required String key,
    required String initialValue,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final controller = TextEditingController(text: initialValue);
    
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.save),
          onPressed: () {
            _sauvegarderParametre(key, controller.text);
            final scaffoldContext = context;
            if (scaffoldContext.mounted) {
              ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                const SnackBar(content: Text('Paramètre sauvegardé')),
              );
            }
          },
        ),
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
    );
  }
}

// ====================== APPLICATION PRINCIPALE ======================

class FinanciaProApp extends StatefulWidget {
  const FinanciaProApp({super.key});
  
  @override
  FinanciaProAppState createState() => FinanciaProAppState();
}

class FinanciaProAppState extends State<FinanciaProApp> {
  bool _initialized = false;
  
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }
  
  Future<void> _initializeApp() async {
    try {
      await DatabaseManager().init();
      setState(() {
        _initialized = true;
      });
    } catch (e) {
      debugPrint('Erreur d\'initialisation: $e');
      // TODO: Gérer l'erreur
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: AppConfig.primaryColor,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 20),
                Text(
                  'Initialisation de Financia Pro...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return MaterialApp(
      title: 'Financia Pro',
      theme: ThemeData(
        primaryColor: AppConfig.primaryColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConfig.primaryColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: AppConfig.primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConfig.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: EdgeInsets.all(16),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: AppConfig.primaryColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConfig.primaryColor,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppConfig.primaryColor,
          elevation: 4,
        ),
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  
  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  
  static const List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),
    ClientsScreen(),
    CreationFactureScreen(),
    ParametresScreen(),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: AppConfig.primaryColor,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard),
            label: 'Tableau de bord',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people),
            label: 'Clients',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.receipt),
            label: 'Facturation',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }
}
