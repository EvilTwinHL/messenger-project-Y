# 🗂 MESSENGER Y — PROJECT CONTEXT
> Вставляй цей файл першим повідомленням у новому чаті.
> Після цього додавай лише той файл, з яким зараз працюєш.

---

## 📦 СТЕК

| Шар | Технологія |
|-----|-----------|
| Клієнт | Flutter 3.x (Android, iOS, Windows) |
| Сервер | Node.js + Express 5 + Socket.IO 4.8 |
| БД | Firebase Firestore (підколекції) |
| Сховище | Firebase Storage (Google Cloud) |
| Push | FCM multicast |
| Auth | Нікнейм + аватар (JWT — ще не додано) |
| OTA | Shorebird Code Push |
| Real-time | Socket.IO rooms + Cloud Firestore StreamBuilder |

---

## 🗂 СТРУКТУРА ФАЙЛІВ

```
client/
└── lib/
    ├── main.dart                  # Точка входу, MyApp, ChatScreen, LoginScreen (ПОТРІБНО РОЗБИТИ)
    ├── home_screen.dart           # HomeScreen, _OvalNavBar, вкладки Чати/Контакти/Налаштування/Акаунт
    ├── login_screen.dart          # LoginScreen (є дублікат у main.dart — це баг)
    ├── search_screen.dart         # SearchUserScreen — пошук юзерів, старт DM
    ├── settings_screen.dart       # SettingsScreen — OTA, профіль, сповіщення, logout
    ├── signal_context_menu.dart   # SignalContextMenu — overlay з реакціями та діями
    ├── audio_player_widget.dart   # AudioMessagePlayer — waveform плеєр Signal-стиль
    ├── voice_recorder.dart        # VoiceRecorder widget — запис з анімацією (окремий файл)
    └── theme.dart                 # SignalColors, AppSizes, AppTheme — ВСІ токени тут

server/
└── index.js                      # Express + Socket.IO + Firebase Admin — весь сервер в одному файлі
```

### Що ЩЕ ПОТРІБНО створити (технічний борг):
```
client/lib/
    ├── screens/                   # Перемістити ChatScreen, HomeScreen, LoginScreen сюди
    ├── widgets/                   # MessageBubble, SwipeToReply, TypingIndicator, DateSeparator
    ├── services/
    │   ├── socket_service.dart    # Інкапсулювати Socket.IO логіку
    │   └── auth_service.dart      # JWT, login, logout, refresh
    ├── utils/
    │   └── date_utils.dart        # formatTime() — зараз дублюється у 2 місцях
    └── config/
        └── app_config.dart        # serverUrl з .env (зараз hardcode)
```

---

## ⚙️ ВАЖЛИВІ КОНСТАНТИ

```dart
// main.dart
const String serverUrl = 'https://pproject-y.onrender.com';
bool firebaseAvailable = false; // глобальний флаг — false на Windows
```

```javascript
// server/index.js
const PORT = process.env.PORT || 3000;
const BUCKET_NAME = "project-y-8df27.firebasestorage.app";
// maxHttpBufferSize: 6e7  ← БАГИ: занадто великий (60MB), треба 10e6
```

---

## 🎨 ДИЗАЙН-СИСТЕМА (theme.dart)

```dart
// Всі кольори — тільки через SignalColors, не хардкодити
SignalColors.primary        // #2B5CE6 — акцент, кнопки, активна навігація
SignalColors.appBackground  // #111113 — фон scaffold
SignalColors.surface        // #1A1B1D — AppBar, картки
SignalColors.elevated       // #252528 — модали, контекст-меню
SignalColors.outgoing       // #2B5CE6 — мої бульбашки
SignalColors.incoming       // #2C2C2E — чужі бульбашки
SignalColors.textPrimary    // #FFFFFF
SignalColors.textSecondary  // #8E8E9A

// Всі розміри — тільки через AppSizes
AppSizes.navBarHeight       // 72
AppSizes.bubbleRadius       // 18
AppSizes.avatarRadiusMedium // 27
// тощо...
```

---

## 🔥 FIRESTORE СТРУКТУРА

```
users/{username}
  username, avatarUrl, createdAt
  [ПЛАН] passwordHash, bio, links[], online, lastSeen, isPremium

chats/{chatId}
  type: "dm" | "group"
  participants: [username1, username2]
  lastMessage: { text, sender, timestamp, read }
  [ПЛАН] name, avatarUrl, adminUsername (для груп)
  [ПЛАН] pinnedMessage, autoDeleteAfter

chats/{chatId}/messages/{messageId}
  text, sender, senderAvatar, type, timestamp, read
  replyTo: { id, text, sender }
  reactions: { "❤️": ["user1"], "👍": ["user2"] }
  edited, editedAt
  audioUrl, audioDuration   (для voice)
  [ПЛАН] status: "sent"|"delivered"|"read"
  [ПЛАН] fileUrl, filename, fileSize, mimeType (для docs)

fcm_tokens/{token}
  username, updatedAt
  [ПРОБЛЕМА]: не очищаються невалідні токени

[ПЛАН] stories/{storyId}
  authorUsername, mediaUrl, mediaType, text, createdAt, expiresAt
stories/{storyId}/views/{username}: viewedAt
```

---

## 🔌 SOCKET.IO ПОДІЇ

### Клієнт → Сервер
| Подія | Дані | Опис |
|-------|------|------|
| `join_chat` | chatId | Вхід у кімнату |
| `leave_chat` | chatId | Вихід |
| `send_message` | {chatId, text, sender, type, replyTo?, audioUrl?, audioDuration?} | Надіслати |
| `delete_message` | {messageId, chatId} | Видалити |
| `edit_message` | {messageId, newText, username, chatId} | Редагувати |
| `add_reaction` | {messageId, emoji, username, chatId} | Реакція (toggle) |
| `typing` | {username, chatId} | Індикатор набору |
| `mark_read` | {chatId} | Позначити прочитаним |
| `register_token` | {token, username} | FCM токен |
| `request_history` | chatId | Завантажити 50 повідомлень (тільки Windows) |
| `debug_log` | string | Лог з телефону |

### Сервер → Клієнт
| Подія | Дані | Опис |
|-------|------|------|
| `receive_message` | messageData | Нове повідомлення |
| `load_history` | message[] | Історія (Windows) |
| `message_deleted` | messageId | Видалено |
| `message_edited` | {messageId, newText, edited} | Відредаговано |
| `reaction_updated` | {messageId, reactions} | Реакції оновлено |
| `display_typing` | {username, chatId} | Хтось друкує |
| `message_read_update` | data | Прочитано |

---

## 🌐 REST API

| Метод | Ендпоінт | Опис |
|-------|----------|------|
| POST | `/auth` | Вхід/реєстрація {username, avatarUrl} → {status, user} |
| POST | `/upload` | Завантажити фото → {url} |
| POST | `/upload-audio` | Завантажити аудіо → {url} |
| GET | `/search_users?q=&myUsername=` | Пошук юзерів |
| POST | `/get_or_create_dm` | {myUsername, otherUsername} → {id, ...chat} |
| GET | `/get_user_chats?username=` | Список чатів (для Windows) |
| GET | `/ping` | Health check |

### ПЛАН нових ендпоінтів:
```
POST /auth            → додати password, повертати {token, refreshToken, user}
POST /refresh         → {refreshToken} → {token}
GET  /messages        → ?chatId=&before=<timestamp>&limit=50  (пагінація)
POST /upload-file     → документи PDF/DOCX/ZIP → {url, filename, size, mimeType}
POST /create_group    → {name, participants[], adminUsername}
GET  /users/:username → розширений профіль
PUT  /users/:username → {bio, links}
POST /stories         → {mediaUrl, mediaType, text}
GET  /stories         → активні сторіз згруповані по автору
```

---

## ✅ ЩО РЕАЛІЗОВАНО (17 функцій)

- [x] Приватні чати (DM) — Firestore + Socket.IO rooms
- [x] Авторизація через нікнейм + аватар
- [x] Надсилання фото (Firebase Storage)
- [x] Голосові повідомлення + Waveform плеєр (audio_player_widget.dart)
- [x] Запис голосу з анімацією (voice_recorder.dart + вбудований у ChatScreen)
- [x] Реакції на повідомлення (emoji toggle)
- [x] Reply (відповідь на конкретне повідомлення) + swipe-to-reply
- [x] Редагування та видалення повідомлень
- [x] Signal Dark UI (SignalColors + AppSizes)
- [x] Плаваюча овальна навігація (Telegram-стиль)
- [x] FCM Push Notifications (multicast — є БАГ, надсилає всім)
- [x] Windows підтримка (HTTP fallback + Socket.IO)
- [x] Shorebird OTA-оновлення
- [x] Typing indicator з анімацією крапок
- [x] Розділювачі дат + Scroll Date Overlay
- [x] Контекстне меню Signal-стиль (blur overlay + реакції)
- [x] Пошук користувачів

---

## 🐛 ВІДОМІ БАГИ (виправити першими)

### 🔴 Критичні:
1. **Push всім** — `send_message` надсилає FCM ВСІМ юзерам, не тільки учасникам чату. Виправлення: читати `chat.participants`, фільтрувати `fcm_tokens` за ними.
2. **Дублікат LoginScreen** — є і в `main.dart` і в `login_screen.dart`. Прибрати з `main.dart`.
3. **Немає пароля** — авторизація тільки по нікнейму, будь-хто може зайти під чужим іменем.
4. **Socket без auth** — будь-хто може підключитись і надсилати повідомлення.

### 🟠 Важливі:
5. **`main.dart` ~1400 рядків** — ChatScreen, MessageBubble, SwipeToReply, TypingIndicator тощо — все в одному файлі.
6. **`serverUrl` hardcode** — треба у `.env` через `flutter_dotenv`.
7. **`maxHttpBufferSize = 6e7`** — 60MB, DoS ризик. Зменшити до `10e6`.
8. **`fcm_tokens` не очищаються** — невалідні токени накопичуються.
9. **Немає graceful shutdown** — `process.on('SIGTERM', ...)` відсутній.
10. **`firebaseAvailable` — глобальна змінна** — замінити на DI (get_it або riverpod).

---

## 📱 ОСОБЛИВОСТІ ПЛАТФОРМ

```dart
// Windows: Firebase/Firestore недоступні
if (!firebaseAvailable) {
  // Використовуємо HTTP /get_user_chats та Socket.IO request_history
  // _localMessages — локальний List замість StreamBuilder
}

// Android/iOS: Firestore StreamBuilder (real-time)
// Firebase Messaging + Push Notifications
// Shorebird OTA (тільки Android/iOS)
```

---

## 📦 PUBSPEC ЗАЛЕЖНОСТІ (ключові)

```yaml
socket_io_client: ^3.1.4
firebase_core: ^4.4.0
firebase_messaging: ^16.1.1
cloud_firestore: ^6.1.2
shorebird_code_push: ^2.0.5
image_picker: ^1.2.1
record: ^6.2.0          # Запис аудіо
audioplayers: ^6.5.1    # Відтворення аудіо
audio_waveforms: ^2.0.2 # (є в pubspec, але використовується власний painter)
just_audio: ^0.9.43
vibration: ^3.1.6       # Haptic при swipe-to-reply
permission_handler: ^12.0.1
path_provider: ^2.1.1
shared_preferences: ^2.5.4
http: ^1.6.0
```

---

## 🗓 ПЛАН РОЗВИТКУ (короткий)

| Пріоритет | Задача | Час |
|-----------|--------|-----|
| 🔴 ЗАРАЗ | Виправити push-фільтр по учасниках | 1 день |
| 🔴 ЗАРАЗ | Розбити main.dart на файли | 2 дні |
| 🔴 ЗАРАЗ | Додати пароль + JWT | 3 дні |
| 🟠 Фаза 1 | Rate limiting, helmet, валідація | 1 тиждень |
| 🟠 Фаза 2 | Статуси ✓✓✓, онлайн-статус, пагінація | 2 тижні |
| 🟠 Фаза 2 | Передача документів, групові чати | 3 тижні |
| 🟡 Фаза 2 | WebRTC дзвінки | 1 місяць |
| 🟡 Фаза 3 | Профілі, Сторіз | 1 місяць |
| 🟡 Фаза 4 | DevOps, Redis, CI/CD, тести | 1 місяць |
| ⏳ Фаза 5 | E2EE, монетизація | 2026+ |

---

## 💡 ЯК ВИКОРИСТОВУВАТИ ЦЕЙ ФАЙЛ

```
Новий чат → вставити CONTEXT.md → додати ТІЛЬКИ потрібний файл:

Задача: "виправити push-фільтр"     → додати server/index.js
Задача: "додати пагінацію в чаті"   → додати main.dart (або chat_screen.dart)
Задача: "нові кольори у темі"        → додати theme.dart
Задача: "проблема з аудіо плеєром"  → додати audio_player_widget.dart
Задача: "розбити main.dart"         → додати main.dart
Задача: "щось не так у навігації"   → додати home_screen.dart
```