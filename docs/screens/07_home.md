# 07. Home Screen

## Cél

A fő dashboard, ami áttekintést ad a felhasználó olvasmányairól, és lehetőséget biztosít a gyors folytatásra, valamint új könyvek felfedezésére.

## UI Elemek

A képernyő négy fő szekcióra tagolódik:

1. **Header (Fejléc):**
   - **Köszönés:** A napszak alapján dinamikusan változik (Good morning, Good afternoon, Good evening).
   - **Név:** A felhasználó által megadott `username` a Firestore `users` kollekciójából (valós idejű streamben figyelve).
   - **UserAvatar:** Egy saját fejlesztésű widget, ami a felhasználó nevének kezdőbetűjét jeleníti meg egy körben.
2. **Continue reading (Olvasás folytatása):**
   - `SectionHeader` widget: Cím ("Continue reading").
   - `BookCardHorizontal` widget: A legutóbb olvasott könyv adatai (borító, cím, szerző, oldalszám, százalék, progress bar).
   - **Akciógomb:** Egy "Resume reading" gomb, ami megnyitja a frissítő ablakot (bottom sheet).
3. **Your library (Könyvtárad):**
   - `SectionHeader` widget: Cím ("Your library") és egy "View all" gomb.
   - Vízszintes görgethető lista, ami `LibraryBookCard` widgeteket tartalmaz (borító, cím, szerző, státusz felirat).
   - **Duplikátum szűrés:** Ha egy könyvhöz több bejegyzés is tartozik (pl. újraolvasás miatt), csak a legrelevánsabb jelenik meg (Prioritás: reading > want_to_read > finished).
4. **Popular this week (Népszerű ezen a héten):**
   - `SectionHeader` widget: Cím ("Popular this week") és egy "Explore" gomb.
   - Egy kiemelt könyv részletesebb nézete: nagyobb borító, cím, szerző, dinamikus csillagértékelés, és egy rövid leírás.

## Működés / Logika

- **Köszönés és Név:** A `_getGreeting()` függvény a `DateTime.now().hour` alapján dönti el a köszönést. A név egy `StreamBuilder`-en keresztül folyamatosan figyeli a `users/{uid}` dokumentumot.
- **Valós idejű adatok (Real-time Streams):**
  - A "Continue reading" (`_continueReadingStream`) és a "Your library" (`_libraryStream`) `StreamBuilder`-t használ. 
  - A "Continue reading" a `status == 'reading'` bejegyzéseket rendezi `lastReadAt` alapján.
- **Popular this week (Dinamikus algoritmus):**
  - A kód figyeli az összes `reviews` és `review_comments` bejegyzést.
  - Kiszűri az **elmúlt 7 napban** születetteket, és összeszámolja, melyik `bookId`-hoz mennyi aktivitás (review + komment) tartozik.
  - A legtöbb aktivitással rendelkező könyvet jeleníti meg, kiszámolva annak valós átlagértékelését.
- **Interakciók:**
  - A "Resume reading" gombra kattintva meghívódik a `showUpdateProgressSheet()`.
  - A "View all" gombok a `widget.onNavigateToTab(1)` hívással átváltanak a My Library képernyőre, az "Explore" gomb pedig a `widget.onNavigateToTab(2)` hívással a Discover képernyőre.

## Állapotok

- **Loading (Betöltés):** Amíg a streamek adatot várnak, a képernyő közepén egy `CircularProgressIndicator` forog.
- **Error (Hiba):** Ha bármelyik stream hibát dob, piros szöveggel jelenik meg a hibaüzenet.
- **Empty (Üres):** Ha a felhasználónak nincs olvasás alatt álló könyve, a "Continue reading" szekció a "You are not reading any books currently." szöveget mutatja. Ha a könyvtára üres, a "Your library is empty." szöveget mutatja.

## Screenshotok

![Home Screen](../screenshots/07_home1.png)
![Home Screen](../screenshots/07_home2.png)
![Home Screen](../screenshots/07_home3.png)
