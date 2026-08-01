# RallyGo

RallyGo is an iOS app for tennis players to discover, create, join, and manage tennis events. It includes event discovery, profile onboarding, Google and Apple authentication, notifications, chat rooms, reporting, and Supabase-backed data storage.

## Tech Stack

- SwiftUI
- Xcode
- Supabase Auth, Postgres, Realtime, Edge Functions
- Apple Push Notification service (APNs)
- Google Sign-In through OAuth
- Sign in with Apple

## Project Structure

```text
van-tennis/
├── Config/                 # Local and build configuration files
├── Edge/                   # Supabase Edge Functions
├── Supabase/               # SQL migrations and backend notes
├── van-tennis.xcodeproj/   # Xcode project
└── van-tennis/
    ├── App/                # App shell, navigation, shared styles, widgets, realtime subscription manager
    ├── Assets.xcassets/    # App icons, SVG/image assets, brand, illustrations, photos, UI assets
    ├── Content/            # App copy/content JSON
    ├── Domain/             # Shared models and enums
    ├── Features/           # Feature screens and view models
    ├── Services/           # Auth, Supabase, notification, and API services
    └── Utils/              # Constants, helpers, logger, and shared utilities
```

## Local Setup

1. Open the Xcode project:

   ```bash
   open van-tennis.xcodeproj
   ```

2. Create local config:

   ```bash
   cp Config/Local.example.xcconfig Config/Local.xcconfig
   ```

3. Fill in `Config/Local.xcconfig`:

   ```text
   SUPABASE_PROJECT_URL = https:/$()/YOUR_SUPABASE_PROJECT.supabase.co
   SUPABASE_ANON_KEY = YOUR_SUPABASE_ANON_KEY
   GOOGLE_CLIENT_ID = YOUR_GOOGLE_CLIENT_ID
   GOOGLE_AUTHORIZATION_ENDPOINT = https:/$()/accounts.google.com/o/oauth2/v2/auth
   GOOGLE_TOKEN_ENDPOINT = https:/$()/oauth2.googleapis.com/token
   ```

4. Configure auth providers in Supabase:

   - Google OAuth
   - Apple OAuth
   - Redirect URL schemes in Xcode

5. Run Supabase migrations from `Supabase/migrations`.

6. Deploy Edge Functions from `Edge/` if testing push notifications or server-side notification workflows.

## Build

From the repo root:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project van-tennis.xcodeproj \
  -scheme van-tennis \
  -configuration Debug \
  -sdk iphonesimulator \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Main Features

- Google and Apple authentication
- Profile onboarding with skill level, gender, and social tags
- Discover events with city, skill level, and event type filters
- Create tennis events with city/court selection
- Join request approval/rejection flow
- My Events for hosted and participated events
- Event detail pages with host, participants, chat, report, join, leave, and cancel flows
- Notifications list with unread state, swipe actions, and join request navigation
- Event chat rooms with cached messages and realtime updates
- Account deletion and logout flows
- Reports for safety/moderation

## Backend Notes

Backend schema changes live in `Supabase/migrations`. Edge Functions live in `Edge/`.

The app relies on Supabase for:

- User profiles
- Tennis events
- Notifications
- Device tokens
- Reports
- Chat messages
- Realtime profile/chat updates

## Supabase Realtime

Realtime subscriptions are coordinated by `RealtimeSubscriptionManager` under `van-tennis/App/Subscription`.

### Profiles Subscription

The app subscribes to the current user's row in the `profiles` table. This is the main app-wide realtime channel and should stay active while the user is signed in.

The subscription listens only to the signed-in user's profile row, not the entire `profiles` table. If the socket or channel becomes unhealthy, the profile realtime health monitor checks the subscription on a fixed interval and asks the manager to recover the channel.

### Chat Message Subscription

Chat messages use Supabase Realtime on the `chat_messages` table. When a user enters a chat room, the app subscribes to inserts for that event's chat room so new messages can be appended to the in-memory chat cache and rendered in the visible chat list.

The app also uses a shared chat-message subscription on the chat list page so latest-message previews can update while viewing the conversation list.

### Realtime Design Notes

- Profile realtime and chat realtime use coordinated subscription management to avoid stale channels.
- Chat realtime uses a separate Supabase realtime client/socket from the profile realtime channel to reduce interference between chat room subscriptions and the app-wide profile subscription.
- Realtime is treated as a live update layer, not the source of initial data. Screens still fetch required data when entering or refreshing, then use realtime updates to keep visible/cache state fresh.

## Content and Assets

- User-facing text is stored in `van-tennis/Content/AppContent.json`.
- Shared constants and court mappings live in `van-tennis/Utils/Constants.swift`.
- Images and icons live in `van-tennis/Assets.xcassets`.

## Notes

- Do not commit real secrets in `Config/Local.xcconfig`.
- Keep Supabase migrations append-only unless intentionally correcting local development history.
- Run a simulator build after changing shared enums, content keys, migrations, or asset names.
