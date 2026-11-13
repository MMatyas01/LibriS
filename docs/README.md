# LibriS - Részletes Fejlesztői Dokumentáció

Üdvözlünk a LibriS projekt dokumentációjában! Ez a gyűjtemény azért készült, hogy átfogó képet adjon az alkalmazás felépítéséről, a felhasználói felületről és a mögötte lévő technológiákról.

## Miért ezeket a technológiákat választottuk?

- **Flutter (Dart):** Azért esett a választás a Flutterre, mert egyetlen kódbázisból kiindulva **több felületen is futtatható** (iOS, Android, Web, asztali gépek), így rendkívül hatékony a fejlesztés.
- **Google Cloud Firestore:** A Firestore használata kiemelten népszerű és hatékony Flutter alkalmazások fejlesztésekor. Mivel mindkét technológiát a Google fejleszti, az első osztályú integráció (a FlutterFire pluginokon keresztül) **minimalizálja a backend-fejlesztési időt**, miközben beépített valós idejű szinkronizációt (real-time sync) és offline támogatást biztosít. Ez ideális egy olyan dinamikus alkalmazáshoz, mint a LibriS.

## Tartalomjegyzék

- [Architektúra és Technológia](architecture.md)
- [Adatbázis és Biztonsági Szabályok](firestore.md)

### Képernyők (Screens)

A képernyők a felhasználói folyamat (user flow) sorrendjében vannak listázva:

1. [Splash Screen](screens/01_splash.md)
2. [Login](screens/02_login.md)
3. [Register](screens/03_register.md)
4. [Forgot Password](screens/04_forgot_password.md)
5. [Verify Email](screens/05_verify_email.md)
6. [Main Navigation (Bottom Nav)](screens/06_main_navigation.md)
7. [Home](screens/07_home.md)
8. [Discover](screens/08_discover.md)
9. [My Library](screens/09_my_library.md)
10. [Book Details](screens/10_book_details.md)
11. [Review Details](screens/11_review_details.md)
