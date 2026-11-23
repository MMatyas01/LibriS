# 17. My Reviews Screen

## Cél

A felhasználó által írt review-k és azoknak a review-knak az összegyűjtött megjelenítése, amelyekhez a felhasználó kommentet írt.

## UI Elemek

- **AppBar:** "My reviews" cím és vissza gomb.
- **Your reviews szekció:** A felhasználó összes saját értékelése.
- **Reviews you commented on szekció:** Más felhasználók azon értékelései, amelyekhez az aktuális user kommentet írt.
- **Összecsukható szekciók:** Mindkét lista külön nyitható és csukható.
- **Darabszám badge:** A szekció fejlécében megjelenik a review-k száma.
- **ReviewCard:** Könyvcím, értékelés, review-szöveg és a widget által támogatott akciók.
- **Empty state:** Külön üzenet jelenik meg, ha valamelyik kategória üres.

## Működés / Logika

- **Saját review-k:** A `reviews` kollekcióból a jelenlegi user `userId` értéke alapján töltődnek be.
- **Kommentelt review-k:** A `review_comments` kollekcióból lekéri a saját kommenteket, összegyűjti az egyedi `reviewId` értékeket, majd betölti a kapcsolódó review dokumentumokat.
- **Duplikáció elkerülése:** A saját review nem jelenik meg újra a kommentelt kategóriában.
- **Könyvcím:** A review `bookId` mezője alapján a `books` kollekcióból töltődik be.
- **Rendezés:** Mindkét lista a `createdAt` alapján, legújabbtól a legrégebbiig rendeződik.
- **Navigáció:** A review kártyára kattintva megnyílik a `ReviewDetailsScreen`.
- **Frissítés:** Visszatéréskor és pull-to-refresh használatakor a listák újratöltődnek.
- **Összecsukás:** A "Your reviews" alapból nyitott, a "Reviews you commented on" alapból zárt, így hosszú saját lista esetén sem kell végiggörgetni az oldalt.

## Állapotok

- **Loading:** Adatok betöltése alatt `CircularProgressIndicator`.
- **Empty own reviews:** "No reviews yet".
- **Empty commented reviews:** "No commented reviews yet".
- **Error:** Firebase-hiba esetén `SnackBar`.

## Screenshotok

![My Reviews Screen](../screenshots/17_my_reviews1.jpg)
![Collapsed Review Sections](../screenshots/17_my_reviews1.jpg)
