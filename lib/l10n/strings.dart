/// User-facing text, French first. Plain words, never blame the customer for
/// the network, short enough for a 320dp-wide screen.
class Strings {
  const Strings._();

  // Sign-in
  static const signInTitle = 'Bienvenue sur Djassa';
  static const signInSubtitle = 'Vos maquis, votre pharmacie de garde, vos paiements et vos points, au même endroit.';
  static const username = 'Identifiant';
  static const password = 'Mot de passe';
  static const signIn = 'Se connecter';
  static const signingIn = 'Connexion…';
  static const signInRejected = 'Identifiant ou mot de passe incorrect.';
  static const signOut = 'Se déconnecter';

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
  static const aboutNameLink = 'Que veut dire « djassa » ?';

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
  static const acceptsDjassa = 'Paiement Djassa';
  static const pointsPer100 = 'pt / 100 F';

  // Venue
  static const specialties = 'Spécialités';
  static const hours = 'Horaires';
  static const address = 'Adresse';
  static const phone = 'Téléphone';
  static const payHereHint = 'Au comptoir, scannez le QR code Djassa du commerçant pour payer.';
  static const noPaymentHere = 'Ce lieu n\'accepte pas encore le paiement Djassa.';
  static const yourPointsHere = 'Vos points ici';
  static const rewards = 'Récompenses';
  static const nextReward = 'Prochaine récompense';
  static const unlocked = 'Débloquée';

  // Scan
  static const scanTitle = 'Scannez le QR code';
  static const scanHint = 'Visez le QR code Djassa affiché par le commerçant.';
  static const torch = 'Lampe';
  static const typeCode = 'Saisir le code';
  static const typeCodeHint = 'Code sous le QR (10 caractères)';
  static const checking = 'Vérification du QR code…';
  static const notDjassaQr = 'Ce QR code n\'est pas un QR code de paiement Djassa.';
  static const cameraDenied = 'Autorisez l\'appareil photo pour scanner, ou saisissez le code.';
  static const scannerUnavailable = 'Le scanner ne démarre pas sur ce téléphone. Touchez « Saisir le code » et tapez le code affiché sous le QR.';
  static const validate = 'Valider';

  // Confirm
  static const confirmTitle = 'Confirmer le paiement';
  static const verifiedMerchant = 'Commerçant vérifié par Djassa';
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
  static const fundsNotice = 'L\'argent va directement de votre portefeuille à celui du commerçant. Djassa ne garde jamais votre argent.';
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
      'Payez avec Djassa dans un maquis ou une pharmacie : chaque paiement vous rapporte des points chez ce commerçant.';
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
  static const noCashOut = 'Les points s\'échangent contre des récompenses chez chaque commerçant, pas contre de l\'argent.';
  static const myPayments = 'Mes paiements';
  static const noPaymentsYet = 'Aucun paiement pour le moment';
  static const noPaymentsHint = 'Scannez le QR code d\'un commerçant pour payer avec votre mobile money.';

  // About the name
  static const aboutNameTitle = 'Le mot djassa';
  static const aboutNameGrammar = '/dja.sa/ · nom masculin';
  static const aboutNameOrigin = 'Nouchi — la langue de la rue à Abidjan';
  static const aboutNameSense1 =
      'Marché informel de rue : le marché spontané, au bord de la route ou dans le quartier, où l\'on vend de tout, des habits de seconde main aux téléphones, souvent sans étal officiel ni autorisation.';
  static const aboutNameSense2 =
      'Par extension, la rue, le « quartier » : le monde de l\'économie informelle et de la débrouille quotidienne — un milieu rude et vivant où l\'on s\'en sort grâce aux petits commerces, aux combines et au sens de la rue.';
  static const aboutNameWhy =
      'Djassa, c\'est la vie de tous les jours : trouver son maquis, sa pharmacie de garde, payer simplement et être récompensé d\'être fidèle.';

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
