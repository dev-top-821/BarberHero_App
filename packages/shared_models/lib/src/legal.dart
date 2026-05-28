/// ╔══════════════════════════════════════════════════════════════════╗
/// ║  Legal documents shown in both apps.                               ║
/// ║                                                                    ║
/// ║  Canonical text lives in `Docs/terms/*.md` (human-readable, the    ║
/// ║  version reviewed/agreed with the client). Deployed copies live    ║
/// ║  in each app's `assets/legal/` folder (bundled at build time) so   ║
/// ║  the in-app viewer can render them offline.                        ║
/// ║                                                                    ║
/// ║  To update the wording after launch:                               ║
/// ║   1. Edit `Docs/terms/*.md`.                                       ║
/// ║   2. Copy the changed file(s) into                                 ║
/// ║      `Barber_App/apps/customer/assets/legal/` and                  ║
/// ║      `Barber_App/apps/barber/assets/legal/` (per-app role-         ║
/// ║      specific T&C; the privacy policy is identical in both).       ║
/// ║   3. Bump [kLegalVersion] below AND TERMS_VERSION in               ║
/// ║      Barber_Admin/src/lib/legal.ts to the same new value.          ║
/// ║   4. Redeploy backend + rebuild both apps.                         ║
/// ║                                                                    ║
/// ║  A version bump automatically forces every user to re-accept       ║
/// ║  (the booking / submit-for-review gates require the current        ║
/// ║  version).                                                         ║
/// ╚══════════════════════════════════════════════════════════════════╝
library;

/// Must equal TERMS_VERSION in Barber_Admin/src/lib/legal.ts.
const String kLegalVersion = '1.0';

/// While the placeholder version 'draft-0' is in place the consent UI is
/// hidden and not enforced, so the apps behave exactly as they did
/// before the T&C work. Setting [kLegalVersion] to a real value (and the
/// matching TERMS_VERSION on the server) flips everything on at once.
const bool kLegalEnabled = kLegalVersion != 'draft-0';

/// Bundled-asset path to the role-specific Terms & Conditions.
/// Customer app's `assets/legal/terms-and-conditions.md` ships the
/// customer T&C; barber app's same path ships the barber T&C.
const String kAssetTermsAndConditions = 'assets/legal/terms-and-conditions.md';

/// Bundled-asset path to the shared Privacy Policy (identical in both apps).
const String kAssetPrivacyPolicy = 'assets/legal/privacy-policy.md';
