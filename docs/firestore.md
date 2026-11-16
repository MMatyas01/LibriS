# Adatbázis és Biztonsági Szabályok

## Firestore Kollekciók

### `users`

A regisztrált felhasználók profiljai. Az adatok inicializálása a regisztrációkor történik.

- `email` (String): A felhasználó e-mail címe.
- `username` (String): Alapértelmezetten az e-mail `@` előtti része.
- `profileImage` (String): Profilkép URL (jelenleg üres string).
- `accountVisibility` (String): Alapértelmezetten 'public'. ('private' esetén a user nem tud lájkolni, kommentelni, és a neve "Anonymous"-ként jelenik meg másoknak).
- `createdAt` (Timestamp): A regisztráció időpontja.
- `readingGoal` (Integer | null): Éves olvasási cél.

### `books`

A könyvek központi adatbázisa.

- `title` (String), `author` (String), `coverUrl` (String), `description` (String), `genre` (String), `isbn` (String), `pageCount` (Integer), `publicationYear` (Timestamp), `publisher` (String).

### `library_entries`

A felhasználók saját polcai.

- `userId` (String), `bookId` (String), `status` (String: 'reading', 'want_to_read', 'finished'), `currentPage` (Integer), `progressVisibility` (String), `addedAt` (Timestamp), `lastReadAt` (Timestamp).

### `reviews`

A könyvekhez írt értékelések.

- `userId` (String): Író UID-ja.
- `bookId` (String): Érintett könyv.
- `rating` (Integer): 1-5 közötti egész szám.
- `text` (String): A vélemény szövege.
- `createdAt` (Timestamp), `updatedAt` (Timestamp).
- `likedBy` (Array<String>): Azon felhasználók UID-jai, akik lájkolták. A lájkok számát a tömb hossza adja.

### `review_comments`

A véleményekhez írt hozzászólások.

- `reviewId` (String): Melyik review-hoz tartozik.
- `userId` (String): Író UID-ja.
- `text` (String): A hozzászólás szövege.
- `createdAt` (Timestamp), `updatedAt` (Timestamp).

### `messages`

A felhasználók közötti üzenetváltás (későbbre tervezett).

- `senderId` (String), `receiverId` (String), `content` (String), `sentAt` (Timestamp), `isRead` (Boolean).

### `book_requests`

Új könyvek kérése a központi katalógusba. A beküldött kérés még nem kerül be a `books` kollekcióba, azt adminisztrátor bírálja el.

- `userId` (String): A kérelmező UID-ja.
- `proposedTitle` (String): A javasolt könyv címe (max. 200 karakter).
- `proposedAuthor` (String): A javasolt szerző (max. 200 karakter).
- `isbn` (String | null): Opcionális ISBN szám (max. 20 karakter).
- `publicationYear` (Integer | null): Opcionális kiadási év (1000-2100 között).
- `publisher` (String | null): Opcionális kiadó (max. 200 karakter).
- `imageUrl` (String | null): Opcionális borítókép URL (max. 500 karakter).
- `status` (String): 'pending', 'approved', 'rejected' vagy 'cancelled'.
- `createdAt` (Timestamp): A kérés beküldésének időpontja.
- `reviewedAt` (Timestamp | null): Az elbírálás időpontja (amíg nincs elbírálva, addig null).
- `adminNote` (String): Az adminisztrátor megjegyzése (alapértelmezetten üres string).
- `seenByUserAt` (Timestamp | null): A felhasználó látta-e már az elbírálást (badge-hez).

---

## Indexek (Composite Indexes)

A Firestore-ban az összetett lekérdezésekhez (pl. szűrés + rendezés) egyedi indexek szükségesek. A következő indexek kerültek beállításra a Firebase Console-ön:

1. **`library_entries`**: `status` (Ascending), `userId` (Ascending), `addedAt` (Descending)
2. **`reviews`**: `bookId` (Ascending), `createdAt` (Descending)
3. **`review_comments`**: `reviewId` (Ascending), `createdAt` (Ascending)
*(Megjegyzés: A `book_requests` kollekció a kliensoldali rendezést használja, ezért ahhoz nem szükséges összetett index.)*

---

## Biztonsági Szabályok (Firestore Rules)

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    function isCurrentUser(userId) {
      return isSignedIn()
          && request.auth.uid == userId;
    }

    function userExists(userId) {
      return exists(
        /databases/$(database)/documents/users/$(userId)
      );
    }

    function isPublicUser(userId) {
      return userExists(userId)
          && get(/databases/$(database)/documents/users/$(userId)).data.get('accountVisibility', 'private') == 'public';
    }

    function bookExists(bookId) {
      return exists(
        /databases/$(database)/documents/books/$(bookId)
      );
    }

    function reviewExists(reviewId) {
      return exists(
        /databases/$(database)/documents/reviews/$(reviewId)
      );
    }

    // Books can be read by everyone.
    match /books/{bookId} {
      allow read: if true;
    }

    // Users can manage their own library entries only.
    match /library_entries/{entryId} {
      allow read: if isSignedIn()
                  && request.auth.uid == resource.data.userId;

      allow create: if isSignedIn()
                    && request.auth.uid
                        == request.resource.data.userId
                    && bookExists(
                      request.resource.data.bookId
                    );

      allow update: if isSignedIn()
                    && request.auth.uid
                        == resource.data.userId
                    && request.resource.data.userId
                        == resource.data.userId
                    && request.resource.data.bookId
                        == resource.data.bookId;

      allow delete: if isSignedIn()
                    && request.auth.uid
                        == resource.data.userId;
    }

    // Users can access and update their own profile.
    match /users/{userId} {
      allow create: if isCurrentUser(userId);
      allow update, delete: if isCurrentUser(userId);

      allow read: if isCurrentUser(userId) || (
        isSignedIn() &&
        isPublicUser(request.auth.uid) &&
        resource.data.get('accountVisibility', 'private') == 'public'
      );
    }

    // Reviews are publicly readable.
    match /reviews/{reviewId} {
      allow read: if true;

      allow create: if isSignedIn()
                    && request.resource.data.keys().hasOnly([
                      'userId',
                      'bookId',
                      'rating',
                      'text',
                      'createdAt',
                      'updatedAt'
                    ])
                    && request.resource.data.userId
                        == request.auth.uid
                    && userExists(
                      request.resource.data.userId
                    )
                    && bookExists(
                      request.resource.data.bookId
                    )
                    && request.resource.data.rating
                        is int
                    && request.resource.data.rating >= 1
                    && request.resource.data.rating <= 5
                    && request.resource.data.text
                        is string
                    && request.resource.data.text.size()
                        > 0
                    && request.resource.data.text.size()
                        <= 2000;

      allow update: if isSignedIn()
                    && request.auth.uid
                        == resource.data.userId
                    && request.resource.data.userId
                        == resource.data.userId
                    && request.resource.data.bookId
                        == resource.data.bookId
                    && request.resource.data.createdAt
                        == resource.data.createdAt
                    && request.resource.data.rating
                        is int
                    && request.resource.data.rating >= 1
                    && request.resource.data.rating <= 5
                    && request.resource.data.text
                        is string
                    && request.resource.data.text.size()
                        > 0
                    && request.resource.data.text.size()
                        <= 2000;

      allow delete: if isSignedIn()
                    && request.auth.uid
                        == resource.data.userId;
    }

    // Review comments are publicly readable.
    match /review_comments/{commentId} {
      allow read: if true;

      allow create: if isSignedIn()
                    && request.resource.data.keys().hasOnly([
                      'reviewId',
                      'userId',
                      'text',
                      'createdAt',
                      'updatedAt'
                    ])
                    && request.resource.data.userId
                        == request.auth.uid
                    && reviewExists(
                      request.resource.data.reviewId
                    )
                    && request.resource.data.text
                        is string
                    && request.resource.data.text.size()
                        > 0
                    && request.resource.data.text.size()
                        <= 1000;

      allow update: if isSignedIn()
                    && request.auth.uid
                        == resource.data.userId
                    && request.resource.data.userId
                        == resource.data.userId
                    && request.resource.data.reviewId
                        == resource.data.reviewId
                    && request.resource.data.createdAt
                        == resource.data.createdAt
                    && request.resource.data.text
                        is string
                    && request.resource.data.text.size()
                        > 0
                    && request.resource.data.text.size()
                        <= 1000;

      allow delete: if isSignedIn()
                    && request.auth.uid
                        == resource.data.userId;
    }

    // Messages are visible only to the sender and receiver.
    match /messages/{messageId} {
      allow read: if isSignedIn()
                  && (
                    request.auth.uid
                        == resource.data.senderId
                    || request.auth.uid
                        == resource.data.receiverId
                  );

      allow create: if isSignedIn()
                    && request.resource.data.keys().hasOnly([
                      'senderId',
                      'receiverId',
                      'content',
                      'sentAt',
                      'isRead'
                    ])
                    && request.resource.data.senderId
                        == request.auth.uid
                    && request.resource.data.receiverId
                        is string
                    && userExists(
                      request.resource.data.receiverId
                    )
                    && request.resource.data.content
                        is string
                    && request.resource.data.content.size()
                        > 0
                    && request.resource.data.content.size()
                        <= 2000
                    && request.resource.data.isRead
                        == false;

      allow update: if isSignedIn()
                    && request.auth.uid
                        == resource.data.receiverId
                    && request.resource.data.diff(
                      resource.data
                    ).affectedKeys().hasOnly([
                      'isRead'
                    ])
                    && request.resource.data.isRead
                        is bool;

      allow delete: if isSignedIn()
                    && request.auth.uid
                        == resource.data.senderId;
    }

    // Book requests – a user submits a proposed book for admin review.
    match /book_requests/{requestId} {
      allow read: if isSignedIn()
                  && request.auth.uid
                      == resource.data.userId;

      allow create: if isSignedIn()
                    && request.resource.data.keys().hasOnly([
                      'userId',
                      'proposedTitle',
                      'proposedAuthor',
                      'isbn',
                      'publicationYear',
                      'publisher',
                      'imageUrl',
                      'status',
                      'createdAt',
                      'reviewedAt',
                      'adminNote',
                      'seenByUserAt'
                    ])
                    && request.resource.data.userId
                        == request.auth.uid
                    && request.resource.data.status
                        == 'pending'
                    && request.resource.data.createdAt
                        is timestamp
                    && request.resource.data.reviewedAt
                        == null
                    && request.resource.data.adminNote
                        == ''
                    && request.resource.data.seenByUserAt
                        == null
                    && request.resource.data.proposedTitle
                        is string
                    && request.resource.data.proposedTitle.size()
                        > 0
                    && request.resource.data.proposedTitle.size()
                        <= 200
                    && request.resource.data.proposedAuthor
                        is string
                    && request.resource.data.proposedAuthor.size()
                        > 0
                    && request.resource.data.proposedAuthor.size()
                        <= 200
                    && (request.resource.data.isbn
                          == null
                        || (request.resource.data.isbn
                              is string
                            && request.resource.data.isbn.size()
                              <= 20))
                    && (request.resource.data.publicationYear
                          == null
                        || (request.resource.data.publicationYear
                              is int
                            && request.resource.data.publicationYear
                              >= 1000
                            && request.resource.data.publicationYear
                              <= 2100))
                    && (request.resource.data.publisher
                          == null
                        || (request.resource.data.publisher
                              is string
                            && request.resource.data.publisher.size()
                              <= 200))
                    && (request.resource.data.imageUrl
                          == null
                        || (request.resource.data.imageUrl
                              is string
                            && request.resource.data.imageUrl.size()
                              <= 500));

      // Két engedélyezett update eset:
      //   1) User visszavonja a saját pending kérését (status -> cancelled)
      //   2) User "látott"-ként jelöli az elbírált kérést (seenByUserAt -> now)
      allow update: if isSignedIn()
                    && request.auth.uid
                        == resource.data.userId
                    && (
                      (
                        resource.data.status == 'pending'
                        && request.resource.data.diff(resource.data)
                            .affectedKeys().hasOnly(['status'])
                        && request.resource.data.status
                            == 'cancelled'
                      )
                      ||
                      (
                        resource.data.reviewedAt != null
                        && request.resource.data.diff(resource.data)
                            .affectedKeys().hasOnly(['seenByUserAt'])
                        && request.resource.data.seenByUserAt
                            == request.time
                      )
                    );

      allow delete: if isSignedIn()
                    && request.auth.uid
                        == resource.data.userId
                    && resource.data.status
                        == 'pending';
    }
  }
}
