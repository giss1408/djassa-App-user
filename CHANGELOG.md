# Changelog — Fidelia (customer app)

What each version of the customer app does, newest first. Versions are git
tags (`vX.Y.Z`); each one builds signed APKs (GitHub Releases) and, from
v0.2.0, the bundle for Google Play. The app was called **Djassa** up to
v0.1.7, briefly **Hossouko**, and is **Fidelia** from v0.2.0.

## Unreleased

- **Alertes bons plans**: the bell on the Bons plans tab turns on a
  notification when a shop in your commune, or one of your favourites,
  publishes a deal. Off until you turn it on; at most one alert per shop per
  day; tapping it opens the shop. Your choices stay on the phone (Firebase
  topics, no device token sent to Fidelia). Needs a build with the
  `FIREBASE_*` defines.
- **Network errors in French**: timeouts, no connection, secure-connection
  failures, server unavailable, refused requests and unexpected responses now
  show a French message saying what to do. Signing in with an empty number
  asks for the number instead of showing "The request was refused".

## v0.2.0 — 2026-10-09

First version prepared for Google Play.

- **New name and look: Fidelia**, slogan "La fidélité, ça compte". New
  launcher icon and start-up screen (the green "F" with its orange point).
- **New app ID `com.regisse.fidelia`** (was `ci.djassa…`): it installs as a
  new app.
- **Open the app without an account**: browse shops, pharmacies and deals
  freely; sign in only to pay or see your points.
- **Your consent for points**, asked at sign-in and changeable in Compte:
  withdrawing it erases your points.
- **Paiements en plusieurs fois**: the loyalty tab shows the goods you are
  paying for in installments at a shop, what is paid and what is left.
- **Favourite shops** (star), recent searches and recently viewed shops, kept
  on the phone.
- **Restaurant** as its own category, with its filter, icon and colours.
- **Deal banners** (bon plan, flash, promo) on deal pictures.
- **Aide**: a WhatsApp conversation with the Fidelia team, from 100 points.
- **Delete my account** (Compte → Supprimer mon compte): immediate; your
  number and points are erased, shops keep their sales without your name.
- Payment QRs printed under the old names still scan.
- Targets **Android 16** (API 36), as Google Play requires.

## v0.1.7 — 2026-10-04

- **Sign in with your phone number** and a code received by SMS.
- **Account**: see your number, move the account to a new number, sign out
  other phones, and recover an account after losing the number.
- **Shop photos and videos** on each shop's page.
- **Error reports and usage figures** sent to Fidelia's own server, tied to a
  random install id, never to your number.
- Icon without a background.

## v0.1.6 — 2026-09-30

- **Pay with Wave** through the merchant's own Wave account: the money goes
  straight to the shop, and the app waits for Wave's confirmation.

## v0.1.5 — 2026-09-30

- **QR scanning works on every phone**, offline: the barcode reader is
  bundled in the app.

## v0.1.4 — 2026-09-30

- The brand mark replaces the Flutter logo on the launcher and the start-up
  screen.

## v0.1.3 — 2026-09-30

- Download about half as large.

## v0.1.2 — 2026-09-30

- **Itinéraire**: open directions to a shop or a pharmacy in the maps app.
- Build: the signing key is generated and checked automatically.

## v0.1.1 — 2026-09-30

Build only: the server address must be set at build time.

## v0.1.0 — 2026-09-30

First test version, installed from a link shared on WhatsApp.

- **Explore** the maquis, restaurants, shops and pharmacies of Abidjan, by
  category and commune, with each shop's page.
- **Pharmacies de garde**: the pharmacies on duty this week, with their number.
- **Bons plans**: the merchants' current deals.
- **Pay by scanning** the merchant's QR code with your mobile money, then get
  a receipt; payment history in the app.
- **Points** at each shop where you pay, and rewards to use at the counter.
- What the name means, from the sign-in screen.
