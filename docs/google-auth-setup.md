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

## 4. Create Android Client ID (Mobile App)
1. In **APIs & Services** > **Credentials**, click **Create Credentials** > **OAuth client ID**.
2. Application type: **Android**.
3. Name: `Boored Android Debug`.
4. Package name: `com.boored.boored`
5. SHA-1 certificate fingerprint:
   ```
   A0:C2:AF:2D:75:5E:2E:9C:6A:97:85:45:42:C5:BE:2E:16:E8:30:F0
   ```
   *(Retrieved directly from your local `~/.android/debug.keystore`)*
6. Click **Create**.

> [!NOTE]
> When generating a production release build later, run `keytool -list -v -keystore <your-release-key.jks>` and add a second Android Client ID with the release SHA-1 fingerprint.

---

## Summary of Credentials Needed
| Credential | Value / Location | Used By |
|---|---|---|
| Package Name | `com.boored.boored` | Android OAuth Client |
| Debug SHA-1 | `A0:C2:AF:2D:75:5E:2E:9C:6A:97:85:45:42:C5:BE:2E:16:E8:30:F0` | Android OAuth Client |
| Web Client ID | From Step 3 | `.env` (`GOOGLE_CLIENT_ID`) & Flutter `serverClientId` |
