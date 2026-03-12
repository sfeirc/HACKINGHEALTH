/// French strings for the app (Apple HIG–oriented UI copy).
abstract class AppStrings {
  // App
  static const String appTitle = 'Dent ta Maison';

  // Home
  static const String takePhoto = 'Prendre une photo';
  static const String importImage = 'Importer une image';
  static const String guidedCapture = 'Prise guidée';
  static const String guidedCaptureSubtitle = 'On vous aide à obtenir une image nette';
  static const String preScreening = 'Pré-dépistage';
  static const String preScreeningSubtitle = 'Contrôle qualité → détection des caries → score 1–100';
  static const String plainLanguageResult = 'Résultat en langage clair';
  static const String plainLanguageResultSubtitle = 'Explication simple et prochaines étapes';
  static const String disclaimer = 'Pas un diagnostic. À titre indicatif uniquement.';

  // Home errors
  static const String photoPickerFailed = 'Impossible d\'ouvrir les photos.';
  static const String importNotSupported = 'Import non pris en charge sur cet appareil. Utilisez un téléphone ou l\'app web.';
  static const String couldNotOpenPicker = 'Impossible d\'ouvrir la galerie.';
  static const String uploadFailedApi = 'Envoi impossible. L’API est-elle démarrée ?';

  // Camera
  static const String noCamerasFound = 'Aucune caméra trouvée.';
  static const String cameraPermissionDenied = 'Accès à la caméra refusé.';
  static const String cameraNotAvailable = 'Appareil photo non disponible (ex. Mac). Utilisez « Importer une image » sur l’écran d’accueil.';
  static const String backToHome = 'Retour à l’accueil';
  static const String tryAgain = 'Réessayer';
  static const String openingCamera = 'Ouverture de l’appareil photo…';
  static const String takePicture = 'Prendre la photo';
  static const String analyzing = 'Analyse en cours…';
  static const String uploadFailed = 'Envoi impossible';
  static const String skipDemo = 'Passer';
  static const String demoIgnore = 'Ignorez';
  static const String demoNextStep = 'Passez à l\'étape suivante';
  static const String demoPlaceholderHint = 'Placez votre bouche ici';
  static const String demoOverlayTitle = 'Cadrez votre bouche dans l\'ovale';

  // Camera instructions (map from scorer English)
  static String instructionFromScorer(String en) {
    switch (en) {
      case 'Position your mouth in the frame':
        return 'Placez votre bouche dans le cadre';
      case 'Open your mouth more':
        return 'Ouvrez un peu plus la bouche';
      case 'Move closer':
        return 'Rapprochez-vous';
      case 'More light needed':
        return 'Plus de lumière nécessaire';
      case 'Hold still':
        return 'Restez immobile';
      default:
        return en;
    }
  }

  // Result
  static const String result = 'Résultat';
  static const String yourResult = 'Votre résultat';
  static const String newScan = 'Nouveau scan';
  static const String retakePhoto = 'Reprendre une photo';
  /// Title when the photo was rejected (blur, dark, not intraoral).
  static const String retakePhotoTitle = 'Photo à reprendre';
  /// Generic reason when no specific reason from backend.
  static const String retakePhotoReasonGeneric =
      'La photo n\'est pas assez nette ou ne montre pas l\'intérieur de la bouche. Reprenez une photo en visant bien l\'intérieur de la bouche, avec une bonne lumière.';
  /// Shown under "Impossible de charger le résultat" to suggest retry/retake.
  static const String failedToLoadResultHint =
      'Vérifiez votre connexion ou reprenez une photo.';
  static const String failedToLoadResult = 'Impossible de charger le résultat';
  static const String analysisFailed = 'Analyse échouée';
  static const String cavityDetected = 'Cavité détectée';
  static const String noCavityDetected = 'Aucune cavité détectée';
  /// Subtitle when no cavity but there are findings (zones à surveiller).
  static const String attentionZoneSubtitle = 'Une zone d\'attention a été repérée';
  static const String yes = 'Oui';
  static const String no = 'Non';
  static const String dangerScore = 'Score de gravité';
  static const String imageQuality = 'Qualité de l’image';
  static const String good = 'Bonne';
  static const String couldBeBetter = 'À améliorer';
  static const String findings = 'Constats';
  /// Section title when there are findings but no definite cavity.
  static const String zonesToMonitor = 'Zones à surveiller';
  static const String severityLow = 'faible';
  static const String severityModerate = 'modéré';
  static const String severityHigh = 'élevé';
  static String severity(String en) {
    switch (en.toLowerCase()) {
      case 'moderate': return severityModerate;
      case 'high': return severityHigh;
      default: return severityLow;
    }
  }
  static const String whyThisResult = 'Pourquoi ce résultat';
  static const String takeAnotherPhoto = 'Prendre une autre photo';
  static const String analyzingYourImage = 'Analyse de votre image…';
  static const String usuallyTakesFewSeconds = 'Cela prend en général quelques secondes';

  // Post-analysis form (user info for admin)
  static const String analysisComplete = 'Analyse terminée';
  static const String fillFormBelow = 'Renseignez vos coordonnées ci-dessous pour enregistrer le résultat.';
  static const String firstName = 'Prénom';
  static const String lastName = 'Nom';
  static const String phone = 'Téléphone';
  static const String dateOfBirth = 'Date de naissance';
  static const String gender = 'Sexe';
  static const String genderMale = 'Homme';
  static const String genderFemale = 'Femme';
  static const String genderOther = 'Autre';
  static const String locationOfBirth = 'Lieu de naissance';
  static const String send = 'Envoyer';
  static const String sending = 'Envoi…';
  static const String formSentSuccess = 'Merci, vos informations ont été enregistrées.';
  static const String formSendFailed = 'L\'envoi a échoué. Réessayez.';

  // API errors
  static const String serverUnreachable = 'Serveur injoignable. Vérifiez que l’API tourne et que l’adresse (api_config) correspond à votre machine.';
  static String cannotReachServer(String url) => 'Impossible de joindre le serveur. L’API tourne-t-elle à $url ? Téléphone et ordinateur doivent être sur le même Wi‑Fi.';
  static String uploadFailedStatus(int code) => 'Envoi impossible ($code). Vérifiez les logs de l’API.';
  static String uploadFailedGeneric(String detail) => 'Envoi impossible : $detail';

  // Overlay
  static const String uploadingAnalyzing = 'Envoi et analyse…';
  static const String gaugeOf100 = 'sur 100';

  /// Region codes from ML → French label for display.
  static String regionLabel(String code) {
    const map = {
      'upper_left_molar_area': 'Zone molaire supérieure gauche',
      'upper_right_molar_area': 'Zone molaire supérieure droite',
      'upper_right_incisor_area': 'Zone incisive/canine supérieure droite',
      'lower_left_molar_area': 'Zone molaire inférieure gauche',
      'lower_right_molar_area': 'Zone molaire inférieure droite',
      'upper_incisor_area': 'Zone incisive supérieure',
      'lower_incisor_area': 'Zone incisive inférieure',
    };
    return map[code.toLowerCase()] ?? code;
  }

  /// Translate known English recommendation messages to French (fallback when backend sends EN).
  static String translateRecommendation(String message) {
    if (message.contains('Possible suspicious area') && message.contains('Consider consulting')) {
      return zonesToMonitorMessage;
    }
    if (message.contains('Suspicious areas detected') && message.contains('Please consult')) {
      return 'Zones d\'attention repérées. Veuillez consulter un dentiste.';
    }
    if (message.contains('No significant findings')) {
      return 'Aucun constat significatif.';
    }
    return message;
  }

  static const String zonesToMonitorMessage =
      'Une zone d\'attention a été repérée. Il est recommandé de consulter un dentiste pour un contrôle.';

  /// Translate known English explanation strings to French (fallback).
  static String translateSummaryTitle(String title) {
    if (title == 'Analysis complete') return 'Analyse terminée';
    return title;
  }

  static String translateSummaryText(String text) {
    if (text.contains('The image was processed') && text.contains('moderate risk level')) {
      return 'Aucune cavité confirmée. Une zone d\'attention a été repérée. Il est recommandé de consulter un dentiste pour un contrôle.';
    }
    if (text.contains('The image was processed') && text.contains('Consider consulting')) {
      return 'L\'image a été traitée. Consultez un dentiste pour un contrôle complet si besoin.';
    }
    return text;
  }
}
