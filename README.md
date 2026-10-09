# Fidelia — customer app

Flutter app for customers in Abidjan: find a maquis or an on-duty pharmacy,
see deals, pay a merchant's Fidelia QR from a mobile wallet, and earn points.
Talks to the FastAPI backend in [`../fidelia-BE`](../fidelia-BE). Android only.

## Run

```bash
scripts/run-device.sh            # USB phone, backend on this machine
flutter test && flutter analyze  # must be clean before a commit
```

## Test distribution

Testers install from one link shared on WhatsApp: the site's `/app` page.
Signed APKs are published as GitHub Releases by
[`.github/workflows/release.yml`](.github/workflows/release.yml) when a version
tag is pushed:

```bash
scripts/create-signing-key.sh              # once: create the key, add 4 GitHub secrets
git tag v0.1.0 && git push origin v0.1.0   # each release
```

Release builds are never debug-signed. Locally, `scripts/build-release.sh
<https api>` builds the same three APKs (arm64, armv7, universal) if
`android/key.properties` exists (see `key.properties.example`). Full procedure,
including the free backend and Firebase App Distribution:
[`../fidelia-BE/docs/technical/DEPLOY-TEST.md`](../fidelia-BE/docs/technical/DEPLOY-TEST.md).
