/// User-facing text, French first. Plain words, never blame the customer for
/// the network, short enough for a 320dp-wide screen.
class Strings {
  const Strings._();

  // Sign-in
  static const signInTitle = 'Bienvenue sur Fidelia';
  static const signInSubtitle = 'Vos maquis, votre pharmacie de garde, vos paiements et vos points, au même endroit.';
  static const signInPhoneLabel = 'Numéro de téléphone';
  static const signInPhoneHint = '07 12 34 56 78';
  static const signInPhoneHelper = 'Vous recevrez un code par SMS.';
  // Loyalty consent (Law 2013-450, art. 14). Never pre-ticked.
  static const loyaltyConsent =
      "J'accepte que Fidelia garde mon numéro pour relier mes achats chez les commerçants partenaires (y compris mes paiements Wave) et me donner des points. Je peux retirer mon accord à tout moment dans Mon compte.";
  static const loyaltyConsentTitle = 'Points de fidélité';
  static const loyaltyConsentOn = 'Mes achats sont reliés à mon numéro.';
  static const loyaltyConsentOff = 'Vos achats ne vous rapportent pas de points.';
  static const loyaltyWithdrawConfirm = 'Retirer votre accord ?';
  static const loyaltyWithdrawHint =
      'Tous vos points seront effacés et vos achats ne seront plus reliés à votre numéro. Cette action est définitive.';
  static const loyaltyWithdraw = 'Retirer et effacer';
  static String loyaltyErased(int points) => 'Accord retiré. $points points effacés.';
  static const loyaltyGiven = 'Merci ! Vos prochains achats vous rapportent des points.';
  // Favourites and history, kept on the phone only.
  static const favorites = 'Mes favoris';
  static const addFavorite = 'Ajouter aux favoris';
  static const removeFavorite = 'Retirer des favoris';
  static const recentlyViewed = 'Vus récemment';
  static const recentSearches = 'Recherches récentes';
  static const clearHistory = 'Effacer';
  static const forgetSearch = 'Retirer cette recherche';
  // Browsing signed out: sign-in is asked only when it is needed.
  static const signInAction = 'Se connecter';
  static const signInToPay = 'Connectez-vous pour payer et gagner des points.';
  static const signInToSeePoints = 'Connectez-vous pour voir vos points et vos récompenses.';
  static const pointsSignedOut = 'Gagnez des points';
  static const pointsSignedOutHint = 'Connectez-vous';
  // Suggestions to the Fidelia team (unlocked at 100 points).
  static const suggestions = 'Aide';
  static const suggestionsFailed = "WhatsApp n'a pas pu s'ouvrir.";
  // Offer alerts (push), chosen on the phone.
  static const offerAlerts = 'Alertes bons plans';
  static const offerAlertsSwitch = 'Me prévenir des nouveaux bons plans';
  static const offerAlertsHint =
      'Une notification quand un commerce de votre commune ou de vos favoris publie un bon plan. '
      'Au plus une par commerce et par jour.';
  static const offerAlertsCommune = 'Ma commune';
  static const offerAlertsFavoritesOnly = 'Mes favoris seulement';
  static const offerAlertsDenied = 'Autorisez les notifications de Fidelia dans les réglages du téléphone.';
  static const offerAlertsUnavailable = 'Les alertes ne sont pas disponibles dans cette version de l’application.';
  static const offerAlertsOn = 'Alertes activées';
  static const offerAlertsOff = 'Alertes désactivées';
  static const seeOffer = 'Voir';
  // Corner banner on a deal's image.
  static const ribbonBonPlan = 'BON PLAN';
  static const ribbonFlash = 'FLASH';
  static const ribbonPromo = 'PROMO';
  static const signInSendCode = 'Recevoir le code';
  static const signInCodeSentTo = 'Code envoyé par SMS au';
  static const signInCodeLabel = 'Code à 6 chiffres';
  static const signInResendCode = 'Renvoyer le code';
  static const signInChangeNumber = 'Changer de numéro';
  static const signIn = 'Se connecter';
  static const signingIn = 'Connexion…';
  static const signOut = 'Se déconnecter';

  // Shop media
  static const videoTitle = 'Regarder la vidéo ?';
  static const videoCost = 'Elle utilise votre connexion internet.';
  static const videoWatch = 'Regarder';
  static const videoFailed = 'La vidéo n\'a pas pu être lue. Vérifiez votre connexion.';

  // Account and recovery
  static const account = 'Mon compte';
  static const accountNumber = 'Numéro du compte';
  static const changeNumber = 'Changer de numéro';
  static const changeNumberHint = 'Gardez vos points et votre historique sur un nouveau numéro.';
  static const changeNumberIntro = 'Il faut les deux SIM : un code arrive sur l\'ancien numéro, un autre sur le nouveau.';
  static const newPhone = 'Nouveau numéro';
  static const sendCodes = 'Recevoir les codes';
  static const oldNumberCode = 'Code reçu sur l\'ancien numéro';
  static const newNumberCode = 'Code reçu sur le nouveau numéro';
  static const confirmChange = 'Changer de numéro';
  static const numberChanged = 'Votre compte est maintenant sur le';
  static const signOutOthers = 'Déconnecter les autres téléphones';
  static const signOutOthersHint = 'Téléphone perdu ou volé : il perd l\'accès dans l\'heure.';
  static const signOutOthersConfirm = 'Déconnecter tous les autres téléphones ?';
  static const signOutOthersDone = 'Les autres téléphones sont déconnectés.';
  static const deleteAccount = 'Supprimer mon compte';
  static const deleteAccountHint = 'Efface votre numéro et vos points.';
  static const deleteAccountConfirm = 'Supprimer votre compte ?';
  static const deleteAccountWarning =
      'Votre numéro et tous vos points sont effacés, sans retour possible. Les commerçants gardent leurs ventes, sans votre nom.';
  static const deleteAccountAction = 'Supprimer';
  static const accountDeleted = 'Votre compte est supprimé.';
  static const lostNumber = 'Numéro perdu ?';
  static const lostNumberTitle = 'Récupérer mon compte';
  static const lostNumberIntro = 'Votre ancien numéro ne marche plus ? Vérifiez votre nouveau numéro, puis dites-nous qui vous êtes. Fidelia vérifie et transfère votre compte.';
  static const oldPhone = 'Ancien numéro';
  static const recoveryDetails = 'Pour vous reconnaître';
  static const recoveryDetailsHint = 'Votre nom, les maquis ou pharmacies où vous gagnez des points, votre dernier achat…';
  static const sendRequest = 'Envoyer la demande';
  static const requestSent = 'Demande envoyée';
  static const backToSignIn = 'Retour à la connexion';
  static const continueLabel = 'Continuer';

  // Navigation
  static const tabHome = 'Accueil';
  static const tabExplore = 'Explorer';
  static const tabDeals = 'Bons plans';
  static const tabLoyalty = 'Fidélité';
  static const scanToPay = 'Scanner pour payer';
  static const scan = 'Payer';

  // Home
  static const homeTagline = 'Qu\'est-ce qu\'on fait aujourd\'hui ?';
  static const myPoints = 'Mes points fidélité';
  static const points = 'points';
  static const pts = 'pts';
  static const seeRewards = 'Voir mes récompenses';
  static const seeRewardsShort = 'Récompenses';
  static const quickScan = 'Scanner';
  static const quickPharmacy = 'De garde';
  static const onDutyNow = 'De garde maintenant';
  static const seeAll = 'Tout voir';
  static const recentPayments = 'Derniers paiements';
  static const aboutNameLink = 'Pourquoi Fidelia ?';

  // Explore
  static const exploreTitle = 'Explorer';
  static const searchAllHint = 'Poulet braisé, pagne, riz, tresses…';
  static const allCategories = 'Tous';
  static const onDutyBanner = 'Besoin d\'une pharmacie maintenant ?';
  static const onDutyBannerAction = 'Voir celles de garde';
  static const toDiscover = 'À découvrir';
  static const browseByCategory = 'Par catégorie';
  static const featuredDealsHome = 'Bons plans à la une';

  // Deals
  static const dealsTitle = 'Bons plans';
  static const dealsSubtitle = 'Les meilleures offres autour de vous';
  static const featuredDeals = 'À la une';
  static const allDeals = 'Toutes les offres';
  static const sponsored = 'Sponsorisé';
  static const dealBadge = 'Promo';
  static const noDeals = 'Pas de bon plan pour le moment';
  static const noDealsHint = 'Revenez bientôt : les commerçants publient de nouvelles offres chaque semaine.';
  static const dealsHere = 'Bons plans ici';
  static const quickDeals = 'Bons plans';
  static const quickExplore = 'Explorer';

  // Lists
  static const onDutyPharmacies = 'Pharmacies de garde';
  static const onDutyPharmaciesSubtitle = 'Ouvertes jour et nuit cette semaine';
  static const allCommunes = 'Toutes';
  static const noResults = 'Aucun résultat';
  static const noResultsHint = 'Essayez un autre plat ou une autre commune.';
  static const retry = 'Réessayer';
  static const loadFailed = 'Impossible de charger. Vérifiez votre connexion.';
  static const sample = 'Exemple';
  static const sampleNotice = 'Données de démonstration : ces établissements sont fictifs.';
  static const onDuty = 'DE GARDE';
  static const until = 'jusqu\'au';
  static const untilShort = 'De garde jusqu\'au';
  static const noPharmacyOnDuty = 'Aucune pharmacie de garde trouvée pour cette commune.';
  static const call = 'Appeler';
  static const callFailed = 'Impossible d\'ouvrir le téléphone.';
  static const directions = 'Itinéraire';
  static const directionsFailed = 'Impossible d\'ouvrir les cartes.';
  static const directionsApprox = 'Position approximative : recherche par nom et adresse.';
  static const acceptsFidelia = 'Paiement Fidelia';
  static const pointsPer100 = 'pt / 100 F';

  // Venue
  static const specialties = 'Spécialités';
  static const hours = 'Horaires';
  static const address = 'Adresse';
  static const phone = 'Téléphone';
  static const payHereHint = 'Au comptoir, scannez le QR code Fidelia du commerçant pour payer.';
  static const noPaymentHere = 'Ce lieu n\'accepte pas encore le paiement Fidelia.';
  static const yourPointsHere = 'Vos points ici';
  static const rewards = 'Récompenses';
  static const nextReward = 'Prochaine récompense';
  static const unlocked = 'Débloquée';

  // Scan
  static const scanTitle = 'Scannez le QR code';
  static const scanHint = 'Visez le QR code Fidelia affiché par le commerçant.';
  static const torch = 'Lampe';
  static const typeCode = 'Saisir le code';
  static const typeCodeHint = 'Code sous le QR (10 caractères)';
  static const checking = 'Vérification du QR code…';
  static const notFideliaQr = 'Ce QR code n\'est pas un QR code de paiement Fidelia.';
  static const cameraDenied = 'Autorisez l\'appareil photo pour scanner, ou saisissez le code.';
  static const scannerUnavailable = 'Le scanner ne démarre pas sur ce téléphone. Touchez « Saisir le code » et tapez le code affiché sous le QR.';
  static const validate = 'Valider';

  // Confirm
  static const confirmTitle = 'Confirmer le paiement';
  static const verifiedMerchant = 'Commerçant vérifié par Fidelia';
  static const receivedOn = 'Reçu sur';
  static const amountFixed = 'Montant demandé par le commerçant';
  static const amount = 'Montant';
  static const amountHint = '0';
  static const wallet = 'Payer avec';
  static const walletPhone = 'Numéro du portefeuille';
  static const walletPhoneHint = '07 12 34 56 78';
  static const youWillEarn = 'Vous gagnerez';
  static const expiresIn = 'Expire dans';
  static const payAmount = 'Payer';
  static const paying = 'Paiement en cours…';
  static const amountInvalid = 'Montant entre 100 et 2 000 000 F.';
  static const phoneInvalid = 'Numéro de portefeuille invalide.';
  static const fundsNotice = 'L\'argent va directement de votre portefeuille à celui du commerçant. Fidelia ne garde jamais votre argent.';
  static const payNetworkError =
      'Pas de réponse. Votre paiement n\'a peut-être pas abouti : appuyez sur Réessayer, vous ne serez pas débité deux fois.';
  static const sheetTitle = 'Vous allez payer';
  static const sheetTo = 'à';
  static const sheetWith = 'avec';
  static const sheetConfirm = 'Oui, payer maintenant';
  static const cancel = 'Annuler';

  // Receipt
  static const paymentDone = 'Paiement réussi';
  static const paymentFailed = 'Paiement refusé';
  static const paymentPending = 'Paiement en attente';
  static const waveWaitTitle = 'Validez dans Wave';
  static const waveWaitBody = 'Confirmez le paiement dans l\'application Wave, puis revenez ici. Vos points s\'affichent dès que Wave confirme.';
  static const waveOpen = 'Ouvrir Wave';
  static const waveOpenFailed = 'Impossible d\'ouvrir Wave. Vérifiez que l\'application Wave est installée.';
  static const waveChecking = 'En attente de la confirmation de Wave…';
  static const waveStillPending = 'Wave n\'a pas encore confirmé. Vous pouvez fermer : le paiement apparaîtra dans votre historique.';
  static const pointsEarned = 'points gagnés';
  static const reference = 'Référence';
  static const date = 'Date';
  static const paidTo = 'Payé à';
  static const paidWith = 'Portefeuille';
  static const done = 'Terminer';
  static const tryAgain = 'Réessayer le paiement';

  // Loyalty
  static const loyaltyTitle = 'Ma fidélité';
  static const noPointsYet = 'Pas encore de points';
  static const noPointsHint =
      'Payez avec Fidelia dans un maquis ou une pharmacie : chaque paiement vous rapporte des points chez ce commerçant.';
  static const redeem = 'Utiliser';
  static const missing = 'encore';
  static const places = 'commerces';
  static const forReward = 'pour :';
  static const allUnlocked = 'Toutes les récompenses sont débloquées';
  static const remaining = 'restants chez ce commerçant';
  static const history = 'Historique';
  static const voucherTitle = 'Votre bon est prêt';
  static const voucherShow = 'Montrez ce code au commerçant';
  static const earnedAt = 'Gagnés chez';
  static const spentAt = 'Utilisés chez';
  // "Payer en plusieurs fois". Never "crédit": the customer pays first.
  static const layawayTitle = 'Paiements en plusieurs fois';
  static const layawayMoneyNote = 'L\'argent est gardé par le commerçant, pas par Fidelia. Il vous remet le produit quand le prix est atteint.';
  static const layawayPaid = 'payé sur';
  static const layawayRemaining = 'Reste';
  static const layawayBefore = 'avant le';
  static const layawayReady = 'Payé : passez le récupérer';
  static const layawayDelivered = 'Remis';
  static const layawayCancelled = 'Annulé';
  static const layawayRefunded = 'remboursé';
  static const layawayPayments = 'versements';
  static const noCashOut = 'Les points s\'échangent contre des récompenses chez chaque commerçant, pas contre de l\'argent.';
  static const myPayments = 'Mes paiements';
  static const noPaymentsYet = 'Aucun paiement pour le moment';
  static const noPaymentsHint = 'Scannez le QR code d\'un commerçant pour payer avec votre mobile money.';

  // About the name: built on the slogan, no dictionary claim about the word.
  static const aboutNameTitle = 'Le nom Fidelia';
  static const aboutNameGrammar = '« La fidélité, ça compte »';
  static const aboutNameOrigin = 'Notre promesse';
  static const aboutNameSense1 =
      'Chaque achat chez vos commerçants habituels vous rapporte des points, et vos points deviennent des récompenses.';
  static const aboutNameSense2 =
      'Retrouvez votre maquis, votre pharmacie de garde et les bons plans du quartier, et payez simplement avec votre mobile money.';
  static const aboutNameWhy =
      'Fidelia vient de « fidélité » : être fidèle à ses commerçants de tous les jours, et que ça compte.';

  /// Communes offered as filters. Abidjan first; more as venues sign up.
  static const communes = ['Abobo', 'Cocody', 'Koumassi', 'Marcory', 'Plateau', 'Treichville', 'Yopougon'];

  static const _weekdays = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
  static const _months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

  /// "samedi 4 oct. à 8 h" — hand-rolled to avoid pulling in intl for one format.
  static String dateTime(DateTime t) {
    final minutes = t.minute == 0 ? '' : ' ${t.minute.toString().padLeft(2, '0')}';
    return '${_weekdays[t.weekday - 1]} ${t.day} ${_months[t.month - 1]} à ${t.hour} h$minutes';
  }

  /// "4 oct. · 18:32"
  static String shortDateTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.day} ${_months[t.month - 1]} · ${two(t.hour)}:${two(t.minute)}';
  }

  /// "sam. 4 oct." — compact enough for a card.
  static String shortDay(DateTime t) => '${_weekdays[t.weekday - 1].substring(0, 3)}. ${t.day} ${_months[t.month - 1]}';

  /// "Plus que 3 j", "Dernier jour", or a date when it is far off.
  static String dealEnds(DateTime endsAt) {
    final left = endsAt.difference(DateTime.now());
    if (left.inHours < 24) return 'Dernier jour';
    if (left.inDays <= 30) return 'Plus que ${left.inDays} j';
    return 'Jusqu\'au ${endsAt.day} ${_months[endsAt.month - 1]}';
  }

  static String greeting(DateTime now) => now.hour < 12
      ? 'Bonjour'
      : now.hour < 18
          ? 'Bon après-midi'
          : 'Bonsoir';
}
