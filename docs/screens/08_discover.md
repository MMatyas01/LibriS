# 08. Discover Screen

## Cél

Új könyvek felfedezése, keresése a központi katalógusból, a felhasználó könyvtárában való státuszuk (pl. "In your library") megtekintése, valamint kiindulópontként szolgál a könyvkérések (Book Request) és a kamerás könyvfelismerés (Book Recognition) felé.

## UI Elemek

- **Header (Fejléc):**
  - "Discover" cím és "Find your next chapter." alcím.
  - **"Create request" gomb:** Egy `FilledButton.icon` a jobb felső sarokban, ami a `BookRequestScreen`-re visz.
- **Keresősáv (`SearchBarWidget`):** Keresés könyv címére vagy szerzőjére. Kamera ikon és szűrő chipek nélkül.
- **Találatok fejléce:** Pl. "ALL BOOKS" vagy "RESULTS FOR 'keresés'".
- **Könyvlista:** `BookCardHorizontal` widgetek listája. A kártyákon megjelenik:
  - A könyv borítója, címe, szerzője.
  - A felhasználó státusza (pl. "Not in your library", "In your library · Reading").
  - A valós átlagértékelés (pl. "⭐ 4.3" vagy "None"), és egy "View book details →" gomb.
- **Floating Action Button (FAB):** A jobb alsó sarokban elhelyezett kamera ikon, ami a `BookRecognitionScreen`-re visz.
- **Üres állapot (Empty State):** Ha a keresés nem hoz találatot, a "We couldn't find that book." szöveg mellett megjelenik egy **"Request it instead"** gomb.

## Működés / Logika

- **Keresés:** A beírt szöveget kisbetűsíti, és minden gombnyomásra szűri a listát a `books` kollekcióból (title és author alapján).
- **Átlagok kiszámítása (Memóriában):** A teljesítmény érdekében a `DiscoverScreen` egyszerre kéri le az összes `reviews` dokumentumot, és egy `Map`-ben kiszámolja a könyvek átlagát. Így nem kell minden kártyához külön adatbázis-hívást indítani.
- **Könyvtár állapot:** Egy másik `StreamBuilder` figyeli a `library_entries` kollekciót a bejelentkezett userhez, így azonnal látszik, ha egy könyv már megvan a felhasználónak.
- **Navigáció (Könyv kártya):** A kártyára kattintva megnyílik a `BookDetailsScreen`, átadva a `bookId`-t, a könyv adatait (`Map`), a jelenlegi státuszt és az `onNavigateToTab` függvényt (a fülváltáshoz).
- **Navigáció (Könyvkérés):** A "Create request" gombra, vagy üres keresés esetén a "Request it instead" gombra kattintva a `BookRequestScreen` nyílik meg.
- **Navigáció (Könyvfelismerés):** A kamera FAB-ra kattintva a `BookRecognitionScreen` nyílik meg. A navigációnál átadásra kerül a `widget.onNavigateToTab` függvény, hogy a felismerés utáni `BookDetailsScreen`-ről is működjön a fülváltás.

## Állapotok

- **Loading:** A könyvek és review-k betöltése alatt `CircularProgressIndicator`.
- **Empty:** Ha nincs könyv az adatbázisban, vagy a keresés nem hozott találatot, megfelelő szöveges üzenet és a "Request it instead" opció jelenik meg.

## Screenshotok

![Discover Screen](../screenshots/08_discover1.png)
![Discover Screen](../screenshots/08_discover2.png)
