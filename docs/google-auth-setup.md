# Google Cloud Console Setup for Boored

To enable Google Sign-In on Android and token verification on the Hono backend, follow these steps in the Google Cloud Console.

---

## 1. Create / Select Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com/).
2. Create a new project (e.g., `boored-app`) or select an existing one.

---

## 2. Configure OAuth Consent Screen
1. Navigate to **APIs & Services** > **OAuth consent screen**.
2. Select **External** (unless you are using Google Workspace internally) and click **Create**.
3. Fill in:
   - **App name**: `Boored`
   - **User support email**: Your email
   - **Developer contact information**: Your email
4. Scopes: Keep defaults (`email`, `profile`, `openid`).
5. Test users: Add your Google email address while in development mode.

---

## 3. Create Web Client ID (Backend & Server Auth)
*Even for mobile apps, Google Sign-In requires a **Web Application Client ID** to obtain an `idToken` verifiable on a backend.*

1. Navigate to **APIs & Services** > **Credentials**.
2. Click **Create Credentials** > **OAuth client ID**.
3. Application type: **Web application**.
4. Name: `Boored Web / Backend Client`.
5. Authorized redirect URIs: Not strictly needed for mobile ID token exchange, but you can set `http://localhost:3000` for testing.
6. Click **Create**.
7. Copy the generated **Client ID** (format: `XXXXX.apps.googleusercontent.com`).
8. Paste this into your `.env`:
   ```bash
   GOOGLE_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
   ```
   *Also use this same Web Client ID as the `serverClientId` in Flutter's `GoogleSignIn`.*

---

## 4. Create Android Client IDs (Mobile App)

You need **two** Android OAuth client IDs in Google Cloud Console:

### A. Local / GitHub APK Debug Client
1. Application type: **Android**.
2. Name: `Boored Android Debug / Direct APK`.
3. Package name: `com.boored.boored`
4. SHA-1 certificate fingerprint:
   ```
   A0:C2:AF:2D:75:5E:2E:9C:6A:97:85:45:42:C5:BE:2E:16:E8:30:F0
   ```

### B. Google Play App Signing Client (Production / Play Store)
1. In **APIs & Services** > **Credentials**, click **Create Credentials** > **OAuth client ID**.
2. Application type: **Android**.
3. Name: `Boored Google Play Release`.
4. Package name: `com.boored.boored`
5. SHA-1 certificate fingerprint:
   ```
   42:0A:FA:6E:BA:9F:75:4C:26:5A:9D:FF:9B:47:C2:DB:C7:91:AA:49
   ```
6. Click **Create**.

---

## Summary of Credentials Needed
| Credential | Value / Location | Used By |
|---|---|---|
| Package Name | `com.boored.boored` | Android OAuth Clients |
| Debug / Direct APK SHA-1 | `A0:C2:AF:2D:75:5E:2E:9C:6A:97:85:45:42:C5:BE:2E:16:E8:30:F0` | Direct APK Installations |
| Google Play App Signing SHA-1 | `42:0A:FA:6E:BA:9F:75:4C:26:5A:9D:FF:9B:47:C2:DB:C7:91:AA:49` | Google Play Store Installs |
| Web Client ID | From Step 3 | `.env` (`GOOGLE_CLIENT_ID`) & Flutter `serverClientId` |
