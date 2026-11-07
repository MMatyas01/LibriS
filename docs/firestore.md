# Adatbázis és Biztonsági Szabályok

## Firestore Kollekciók

### `users`

A regisztrált felhasználók profiljai. Az adatok inicializálása a regisztrációkor történik.

- `email` (String): A felhasználó e-mail címe.
- `username` (String): Alapértelmezetten az e-mail `@` előtti része.
- `profileImage` (String): Profilkép URL (jelenleg üres string).
- `accountVisibility` (String): Alapértelmezetten 'public'.
- `createdAt` (Timestamp): A regisztráció időpontja (szerveroldali időbélyeg).
- `readingGoal` (Integer | null): Éves olvasási cél (pl. 12, 20). Alapból `null`.

### `books`

A könyvek központi adatbázisa (az alkalmazás katalógusa). A mezők a következők:

- `title` (String): A könyv címe.
- `author` (String): A könyv szerzője.
- `coverUrl` (String): A borító képének URL-je (pl. Imgur link).
- `description` (String): A könyv rövid tartalma/leírása.
- `genre` (String): Műfaj (pl. "Adventure").
- `isbn` (String): A könyv ISBN száma.
- `pageCount` (Integer): Az oldalak száma.
- `publicationYear` (Timestamp): A megjelenés dátuma.
- `publisher` (String): A kiadó neve.

### `library_entries`

A felhasználók saját polcai (egy könyvhöz több bejegyzés is tartozhat, pl. újraolvasás esetén).

- `userId` (String): Tulajdonos UID-ja.
- `bookId` (String): Hivatkozás a `books` kollekcióra.
- `status` (String): 'reading', 'want_to_read', 'finished'.
- `currentPage` (Integer): Jelenlegi oldalszám.
- `progressVisibility` (String): 'private' (alapértelmezett).
- `addedAt`, `lastReadAt` (Timestamp): Időbélyegek a rendezéshez.

## Biztonsági Szabályok (Firestore Rules)

A szabályok biztosítják, hogy mindenki csak a saját adataihoz férjen hozzá.

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    // Könyvek olvasása mindenkinek engedélyezett
    match /books/{bookId} {
      allow read: if true;
    }

    // Library entries – csak a saját bejegyzéseken
    match /library_entries/{entryId} {
      // Olvasás: csak a saját bejegyzések
      allow read: if request.auth != null
                  && request.auth.uid == resource.data.userId;

      // Létrehozás: a payload userId-ja egyezzen a bejelentkezett userrel
      allow create: if request.auth != null
                    && request.auth.uid == request.resource.data.userId;

      // Módosítás és törlés: csak a saját bejegyzéseken
      allow update, delete: if request.auth != null
                            && request.auth.uid == resource.data.userId;
    }

    // Users kollekció
    match /users/{userId} {
      allow create: if request.auth != null && request.auth.uid == userId;
      allow read, update, delete: if request.auth != null
                                  && request.auth.uid == userId;
    }

  }
}
