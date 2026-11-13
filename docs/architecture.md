# Architektúra és Technológia

## Tech Stack

- **Frontend:** Flutter / Dart (Material Design 3)
- **Backend / Adatbázis:** Firebase (Authentication, Cloud Firestore)
- **Helyi tárolás:** `shared_preferences` (SharedPreferencesAsync)

## Projekt Struktúra

- `lib/main.dart`: Az alkalmazás belépési pontja, itt történik a Firebase inicializálása és a téma betöltése.
- `lib/screens/`: A felhasználói felület képernyői (Widgetek).
- `lib/services/`: Üzleti logika (pl. `AuthService` a Firebase hívásokhoz, `PreferencesService` a helyi mentéshez).
- `lib/widgets/`: Újrahasznosítható UI komponensek (pl. `BookCardHorizontal`, `BottomNavbar`).
- `lib/theme/`: Központi téma és színpaletta (`AppColors`, `AppTheme`).

## Állapotkezelés (State Management)

A projekt beépített Flutter megoldásokat használ:

- `StatefulWidget` és `setState` a lokális UI állapotokhoz.
- `StreamBuilder` a valós idejű Firestore adatokhoz (pl. Home és My Library képernyőkön).
- `FutureBuilder` az egyszeri adatlekérésekhez (pl. Popular book a Home-on).

## Kódolási Konvenciók

- A színek a központi `AppColors` osztályból származnak.
- Reszponzivitás: `LayoutBuilder`, `FractionallySizedBox`, `Wrap` és `FittedBox` használata a fix pixelértékek elkerülésére.
- Flutter új verzió miatt az átlátszóságnál `withValues(alpha: 0.3)` van használva.
