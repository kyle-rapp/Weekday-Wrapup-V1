# Firebase setup — Weekday Wrapup

## 1. Create a Firebase project

1. Open [Firebase Console](https://console.firebase.google.com/) → **Add project**.
2. Enable **Google Analytics** only if you want it (optional for this app).

## 2. Add an iOS app

1. Project **Overview** → **Add app** → **iOS**.
2. **Bundle ID** must match Xcode: `rapp-stuff.Weekday-Wrapup-V1`.
3. Download **GoogleService-Info.plist** and **replace** the placeholder file in `Weekday Wrapup V1/GoogleService-Info.plist`.

## 3. Enable Authentication

1. Firebase Console → **Build** → **Authentication** → **Sign-in method**.
2. Enable **Email/Password**.

## 4. Create Firestore

1. **Build** → **Firestore Database** → **Create database**.
2. Start in **test mode** for development (see rules below), then lock down before production.

### Suggested dev rules (replace before shipping)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    match /posts/{postId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
        && request.resource.data.userId == request.auth.uid;
      allow update: if request.auth != null;
      allow delete: if request.auth != null
        && resource.data.userId == request.auth.uid;
    }
  }
}
```

Tighten `update` on `posts` in production (e.g. only `likeCount` / `likedBy` / `reactions` / `userReactions` / `comments` for authenticated users).

## 5. Xcode — Swift Package Manager

The project already references the **firebase-ios-sdk** package with:

- `FirebaseCore`
- `FirebaseAuth`
- `FirebaseFirestore`

If packages do not resolve: **File → Packages → Reset Package Caches**, then build.

## 6. Run the app

1. Build and run on simulator or device.
2. **Sign up** with email/password on first launch.
3. Create a wrapup, tap **Share → Feed** to publish.
4. Open **Feed** to see real-time updates.
