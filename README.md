# WerkRooster iOS app

Deze map bevat een SwiftUI iOS app met dezelfde UI-flow en dezelfde WordPress REST-koppelingen als de Android app in `APK/android`.

## Functionaliteit
- Inloggen via `/auth/login` met WordPress gebruiker + wachtwoord
- Token refresh via `/auth/refresh`
- Dashboard met snelkoppelingen
- Rooster (lijst + kalender)
- Beschikbaarheid (maandkalender + dagbewerking + opslaan)
- Chat (`/chat`) + live stream via SSE (`/chat/stream`)
- Meldingen (`/notifications`) + markeer gelezen
- Ziekmelden (`/sick`)
- Profiel + iCal link openen/kopieren
- Uitloggen (`/auth/logout`)

## Structuur
- `WerkRooster/App`: app entry, shell en centrale state
- `WerkRooster/Core`: API client en lokale opslag
- `WerkRooster/Models`: request/response modellen
- `WerkRooster/Views`: alle schermen

## Project openen
1. Installeer `xcodegen` op je Mac.
2. Genereer het project in deze map:
   ```bash
   cd IOS
   xcodegen generate
   ```
3. Open `WerkRooster.xcodeproj` in Xcode en run op simulator of toestel.

## Opmerking
De app gebruikt `NSAllowsArbitraryLoads = YES` zodat ook testomgevingen zonder strikte TLS werken, net als tijdens Android development. Voor productie kun je dit aanscherpen.
