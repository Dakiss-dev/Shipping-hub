// French/English bilingual support
class AppLocalizations {
  final String languageCode;

  AppLocalizations({this.languageCode = 'en'});

  static final Map<String, Map<String, String>> _translations = {
    // ============ GENERAL ============
    'appName': {'en': 'Shipping Hub', 'fr': 'Shipping Hub'},
    'dashboard': {'en': 'Dashboard', 'fr': 'Tableau de bord'},
    'packages': {'en': 'Packages', 'fr': 'Colis'},
    'customers': {'en': 'Customers', 'fr': 'Clients'},
    'settings': {'en': 'Settings', 'fr': 'Paramètres'},
    'save': {'en': 'Save', 'fr': 'Enregistrer'},
    'cancel': {'en': 'Cancel', 'fr': 'Annuler'},
    'delete': {'en': 'Delete', 'fr': 'Supprimer'},
    'edit': {'en': 'Edit', 'fr': 'Modifier'},
    'close': {'en': 'Close', 'fr': 'Fermer'},
    'search': {'en': 'Search', 'fr': 'Rechercher'},
    'noData': {'en': 'No data yet', 'fr': 'Aucune donnée'},
    'loading': {'en': 'Loading...', 'fr': 'Chargement...'},
    'confirm': {'en': 'Confirm', 'fr': 'Confirmer'},
    'yes': {'en': 'Yes', 'fr': 'Oui'},
    'no': {'en': 'No', 'fr': 'Non'},
    'total': {'en': 'Total', 'fr': 'Total'},
    'undo': {'en': 'Undo', 'fr': 'Annuler'},
    'send': {'en': 'Send', 'fr': 'Envoyer'},
    'markedPaid': {'en': 'Marked as paid', 'fr': 'Marqué comme payé'},
    'markedUnpaid': {'en': 'Marked as unpaid', 'fr': 'Marqué comme impayé'},
    'sentToSenderPromptReceiver': {
      'en': 'Receipt sent to sender. Send to receiver too?',
      'fr': "Reçu envoyé à l'expéditeur. Envoyer aussi au destinataire ?"
    },
    'photoNeedsConnection': {
      'en': 'Package saved. The photo needs a connection and was not attached.',
      'fr':
          "Colis enregistré. La photo nécessite une connexion et n'a pas été jointe."
    },

    // ============ SHIPMENTS ============
    'shipments': {'en': 'Shipments', 'fr': 'Expéditions'},
    'activeShipments': {'en': 'Active Shipments', 'fr': 'Expéditions actives'},
    'newShipment': {'en': 'New Shipment', 'fr': 'Nouvelle expédition'},
    'airShipment': {'en': 'Air Shipment', 'fr': 'Expédition aérienne'},
    'seaShipment': {'en': 'Sea Shipment', 'fr': 'Expédition maritime'},
    'air': {'en': 'Air', 'fr': 'Aérien'},
    'sea': {'en': 'Sea', 'fr': 'Maritime'},
    'shipmentName': {'en': 'Shipment Name', 'fr': 'Nom de l\'expédition'},
    'destination': {'en': 'Destination', 'fr': 'Destination'},
    'departureDate': {'en': 'Departure Date', 'fr': 'Date de départ'},
    'status': {'en': 'Status', 'fr': 'Statut'},
    'open': {'en': 'Open', 'fr': 'Ouvert'},
    'closed': {'en': 'Closed', 'fr': 'Fermé'},
    'inTransit': {'en': 'In Transit', 'fr': 'En transit'},
    'delivered': {'en': 'Delivered', 'fr': 'Livré'},
    'selectShipmentType': {
      'en': 'Select Shipment Type',
      'fr': 'Sélectionner le type d\'expédition'
    },

    // ============ PACKAGES ============
    'newPackage': {'en': 'New Package', 'fr': 'Nouveau colis'},
    'addPackage': {'en': 'Add Package', 'fr': 'Ajouter un colis'},
    'packagePhoto': {'en': 'Package Photo', 'fr': 'Photo du colis'},
    'takePhoto': {'en': 'Take Photo', 'fr': 'Prendre une photo'},
    'chooseFromGallery': {
      'en': 'Choose from Gallery',
      'fr': 'Choisir depuis la galerie'
    },
    'weight': {'en': 'Weight (kg)', 'fr': 'Poids (kg)'},
    'price': {'en': 'Price', 'fr': 'Prix'},
    'calculatedPrice': {'en': 'Calculated Price', 'fr': 'Prix calculé'},
    'description': {'en': 'Description', 'fr': 'Description'},
    'notes': {'en': 'Notes', 'fr': 'Notes'},
    'referenceNumber': {'en': 'Ref #', 'fr': 'Réf #'},
    'selectItem': {
      'en': 'Select Item Type',
      'fr': 'Sélectionner le type d\'article'
    },
    'presetItem': {'en': 'Preset Item', 'fr': 'Article prédéfini'},
    'customWeight': {'en': 'Custom (by weight)', 'fr': 'Personnalisé (au poids)'},
    'orEnterWeight': {
      'en': 'Or enter weight for custom pricing',
      'fr': 'Ou entrez le poids pour un prix personnalisé'
    },

    // ============ CUSTOMERS ============
    'newCustomer': {'en': 'New Customer', 'fr': 'Nouveau client'},
    'addCustomer': {'en': 'Add Customer', 'fr': 'Ajouter un client'},
    'selectCustomer': {
      'en': 'Select Customer',
      'fr': 'Sélectionner un client'
    },
    'customerName': {'en': 'Customer Name', 'fr': 'Nom du client'},
    'phone': {'en': 'Phone', 'fr': 'Téléphone'},
    'email': {'en': 'Email', 'fr': 'Email'},

    // ============ PAYMENT ============
    'paid': {'en': 'Paid', 'fr': 'Payé'},
    'unpaid': {'en': 'Unpaid', 'fr': 'Non payé'},
    'markAsPaid': {'en': 'Mark as Paid', 'fr': 'Marquer comme payé'},
    'markAsUnpaid': {'en': 'Mark as Unpaid', 'fr': 'Marquer comme non payé'},
    'paymentStatus': {'en': 'Payment', 'fr': 'Paiement'},
    'totalRevenue': {'en': 'Total Revenue', 'fr': 'Revenu total'},
    'outstanding': {'en': 'Outstanding', 'fr': 'En attente'},
    'collected': {'en': 'Collected', 'fr': 'Encaissé'},

    // ============ SHARE ============
    'shareReceipt': {'en': 'Share Receipt', 'fr': 'Partager le reçu'},
    'shareViaWhatsApp': {
      'en': 'Share via WhatsApp',
      'fr': 'Partager via WhatsApp'
    },
    'receiptShared': {'en': 'Receipt shared!', 'fr': 'Reçu partagé!'},

    // ============ SETTINGS ============
    'language': {'en': 'Language', 'fr': 'Langue'},
    'english': {'en': 'English', 'fr': 'Anglais'},
    'french': {'en': 'French', 'fr': 'Français'},
    'pricing': {'en': 'Pricing', 'fr': 'Tarification'},
    'airPricing': {'en': 'Air Pricing', 'fr': 'Tarifs aériens'},
    'seaPricing': {'en': 'Sea Pricing', 'fr': 'Tarifs maritimes'},
    'pricePerKg': {'en': 'Price per kg', 'fr': 'Prix au kg'},
    'currency': {'en': 'Currency', 'fr': 'Devise'},
    'operatorName': {'en': 'Business Name', 'fr': 'Nom de l\'entreprise'},
    'aboutApp': {'en': 'About', 'fr': 'À propos'},
    'fromContacts': {'en': 'From Contacts', 'fr': 'Depuis les contacts'},
    'importFromContacts': {
      'en': 'Import from Contacts',
      'fr': 'Importer depuis les contacts'
    },
    'searchContacts': {
      'en': 'Search contacts...',
      'fr': 'Rechercher des contacts...'
    },
    'contactAdded': {'en': 'added from contacts!', 'fr': 'ajouté depuis les contacts!'},
    'contactExists': {
      'en': 'already in your customers!',
      'fr': 'déjà dans vos clients!'
    },

    // ============ RECEIVER ============
    'receiver': {'en': 'Receiver (Destinataire)', 'fr': 'Destinataire'},
    'receiverName': {'en': 'Receiver Name', 'fr': 'Nom du destinataire'},
    'receiverPhone': {'en': 'Receiver Phone', 'fr': 'Téléphone du destinataire'},
    'receiverHint': {
      'en': 'Person picking up the package at destination',
      'fr': 'Personne qui récupère le colis à destination'
    },
    'sendToSender': {'en': 'Send to Sender', 'fr': 'Envoyer à l\'expéditeur'},
    'sendToReceiver': {
      'en': 'Send to Receiver',
      'fr': 'Envoyer au destinataire'
    },
    'sendToBoth': {'en': 'Send to Both', 'fr': 'Envoyer aux deux'},
    'shareWith': {'en': 'Share with...', 'fr': 'Partager avec...'},

    // ============ STATS ============
    'totalPackages': {'en': 'Total Packages', 'fr': 'Total colis'},
    'totalWeight': {'en': 'Total Weight', 'fr': 'Poids total'},
    'totalValue': {'en': 'Total Value', 'fr': 'Valeur totale'},

    // ============ DESTINATIONS ============
    'burkinaFaso': {'en': 'Burkina Faso', 'fr': 'Burkina Faso'},
    'ivoryCoast': {'en': 'Ivory Coast', 'fr': 'Côte d\'Ivoire'},
    'togo': {'en': 'Togo', 'fr': 'Togo'},
    'ghana': {'en': 'Ghana', 'fr': 'Ghana'},
    'senegal': {'en': 'Senegal', 'fr': 'Sénégal'},
    'mali': {'en': 'Mali', 'fr': 'Mali'},

    // ============ SEA ITEMS ============
    'smallBarrel': {'en': 'Small Barrel', 'fr': 'Petit baril'},
    'largeBarrel': {'en': 'Large Barrel', 'fr': 'Grand baril'},
    'car': {'en': 'Car / Vehicle', 'fr': 'Voiture / Véhicule'},
    'mattress': {'en': 'Mattress', 'fr': 'Matelas'},
    'television': {'en': 'Television', 'fr': 'Télévision'},
    'furniture': {'en': 'Furniture', 'fr': 'Mobilier'},
    'electronics': {'en': 'Electronics', 'fr': 'Électronique'},
  };

  String t(String key) {
    final translations = _translations[key];
    if (translations == null) return key;
    return translations[languageCode] ?? translations['en'] ?? key;
  }
}
