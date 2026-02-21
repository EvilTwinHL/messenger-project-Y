# 🗂 MESSENGER Y — PROJECT CONTEXT v2.3.5
> Вставляй цей файл першим повідомленням у новому чаті.
> Після цього додавай ТІЛЬКИ той файл, з яким зараз працюєш.

---

## 📦 СТЕК

| Шар | Технологія |
|-----|-----------|
| Клієнт | Flutter 3.x (Android, iOS, Windows) |
| Сервер | Node.js 20 + Express 5 + Socket.IO 4.8 |
| БД | Firebase Firestore |
| Сховище | Firebase Storage |
| Push | FCM multicast (фільтр по учасниках ✅) |
| Auth | Нікнейм + аватар (JWT — Фаза 1, ще не зроблено) |
| OTA | Shorebird Code Push |
| Real-time | Socket.IO rooms + Firestore StreamBuilder |
| Config | flutter_dotenv (.env файл) |

---

## 🗂 СТРУКТУРА ФАЙЛІВ (актуальна після рефакторингу)

```
client/
├── .env                           # SERVER_URL=https://pproject-y.onrender.com
├── pubspec.yaml
└── lib/
    ├── config/
    │   └── app_config.dart        # AppConfig.serverUrl (з .env) + AppConfig.firebaseAvailable
    ├── services/
    │   └── socket_service.dart    # SocketService singleton — всі Socket.IO методи
    ├── utils/
    │   └── date_utils.dart        # ChatDateUtils: formatTime, dateLabel, parseDate, isSameDay
    ├── widgets/
    │   ├── message_bubble.dart    # MessageBubble
    │   ├── swipe_to_reply.dart    # SwipeToReply
    │   ├── typing_indicator.dart  # TypingIndicator
    │   ├── date_separator.dart    # DateSeparator
    │   ├── reply_preview.dart     # ReplyPreview
    │   └── reaction_widgets.dart  # ReactionPicker + ReactionsDisplay
    ├── main.dart                  # MyApp, main(), ChatScreen, AppColors, GlassBox
    ├── home_screen.dart           # HomeScreen + _OvalNavBar
    ├── login_screen.dart          # LoginScreen (єдине місце!)
    ├── search_screen.dart         # SearchUserScreen
    ├── settings_screen.dart       # SettingsScreen — OTA, logout (без leading у AppBar!)
    ├── signal_context_menu.dart   # SignalContextMenu overlay
    ├── audio_player_widget.dart   # AudioMessagePlayer + WaveformPainter
    ├── voice_recorder.dart        # VoiceRecorder widget
    └── theme.dart                 # SignalColors, AppSizes, AppTheme

server/
└── index.js                      # Express + Socket.IO + Firebase Admin
```

---

## ⚙️ ВАЖЛИВІ КОНСТАНТИ ТА ПРАВИЛА

```dart
// config/app_config.dart
class AppConfig {
  static String get serverUrl =>
    dotenv.env['SERVER_URL'] ?? 'https://pproject-y.onrender.com';
  static bool firebaseAvailable = false; // встановлюється у main()
}

// main.dart — більше НЕ має:
// const String serverUrl = '...'   ← ВИДАЛЕНО
// bool firebaseAvailable = false;  ← ПЕРЕМІЩЕНО в AppConfig

// Використання у файлах:
// AppConfig.serverUrl              замість старого serverUrl
// AppConfig.firebaseAvailable      замість старого firebaseAvailable

// date_utils.dart — клас називається ChatDateUtils (НЕ DateUtils!)
// Причина: конфлікт з вбудованим Flutter DateUtils з material.dart
// Імпорт: import 'utils/date_utils.dart' as AppDate;
// Виклик: AppDate.ChatDateUtils.formatTime(ts)
```

```javascript
// server/index.js — ключові налаштування
const io = new Server(server, {
  cors: { origin: "*" },
  maxHttpBufferSize: 1e7,  // 10MB (було 60MB — DoS ризик)
  pingTimeout: 60000,
  pingInterval: 25000,
});

// Graceful shutdown (в кінці файлу)
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
```

---

## 🎨 ДИЗАЙН-СИСТЕМА (theme.dart)

```dart
// ЗАВЖДИ використовувати SignalColors і AppSizes — не хардкодити!
SignalColors.primary        // #2B5CE6 — акцент, кнопки
SignalColors.appBackground  // #111113 — фон scaffold
SignalColors.surface        // #1A1B1D — AppBar, картки
SignalColors.elevated       // #252528 — модали, меню
SignalColors.outgoing       // #2B5CE6 — мої бульбашки
SignalColors.incoming       // #2C2C2E — чужі бульбашки
SignalColors.textPrimary    // #FFFFFF
SignalColors.textSecondary  // #8E8E9A
SignalColors.danger         // червоний для помилок/видалення
SignalColors.online         // зелений для онлайн-статусу

AppSizes.navBarHeight       // 72
AppSizes.bubbleRadius       // 18
AppSizes.avatarRadiusMedium // 27
AppSizes.avatarRadiusLarge  // 36
AppSizes.inputHeight        // мін. висота поля вводу
AppSizes.actionButtonSize   // кнопка відправки
```

---

## 🔥 FIRESTORE СТРУКТУРА

```
users/{username}
  username, avatarUrl, createdAt
  [ПЛАН Ф1] passwordHash, bio, online, lastSeen

chats/{chatId}
  type: "dm"                        ← групи планується у Фазі 2
  participants: [username1, username2]
  lastMessage: { text, sender, timestamp, read }

chats/{chatId}/messages/{messageId}
  text, sender, senderAvatar, type  ← "text" | "image" | "voice"
  timestamp, read, edited, editedAt
  replyTo: { id, text, sender }
  reactions: { "❤️": ["user1"], "👍": ["user2"] }
  audioUrl, audioDuration
  [ПЛАН Ф2] status: "sent"|"delivered"|"read"
  [ПЛАН Ф2] fileUrl, filename, fileSize, mimeType

fcm_tokens/{token}
  username, updatedAt
  ✅ Автоматично видаляються невалідні (registration-token-not-registered)
```

---

## 🔌 SOCKET.IO — SocketService методи

```dart
// Використовувати ТІЛЬКИ через SocketService — не socket.emit напряму!
final _socketSvc = SocketService();

_socketSvc.init()
_socketSvc.connect() / disconnect()
_socketSvc.joinChat(chatId)
_socketSvc.leaveChat(chatId)
_socketSvc.sendMessage(data)
_socketSvc.deleteMessage(msgId, chatId)
_socketSvc.editMessage(msgId, text, user, chatId)
_socketSvc.addReaction(msgId, emoji, user, chatId)
_socketSvc.emitTyping(username, chatId)
_socketSvc.markRead(chatId, username)
_socketSvc.registerToken(token, username)
_socketSvc.requestHistory(chatId)
_socketSvc.on(event, handler)
_socketSvc.isConnected                  // bool
_socketSvc.socket                       // IO.Socket (прямий доступ тільки для debug)
_socketSvc.dispose()
```

### Socket події сервер → клієнт
| Подія | Дані |
|-------|------|
| `receive_message` | messageData |
| `load_history` | message[] |
| `message_deleted` | messageId |
| `message_edited` | { messageId, newText, edited } |
| `reaction_updated` | { messageId, reactions } |
| `display_typing` | { username, chatId } |
| `message_read_update` | data |

---

## 🌐 REST API

| Метод | Ендпоінт | Опис |
|-------|----------|------|
| POST | `/auth` | { username, avatarUrl } → { status, user } |
| POST | `/upload` | фото → { url } |
| POST | `/upload-audio` | аудіо → { url } |
| GET | `/search_users?q=&myUsername=` | пошук |
| POST | `/get_or_create_dm` | { myUsername, otherUsername } → chat |
| GET | `/get_user_chats?username=` | список чатів (Windows) |
| GET | `/ping` | health check |

---

## ✅ ЩО РЕАЛІЗОВАНО (17 функцій)

- [x] Приватні чати (DM) — Firestore + Socket.IO
- [x] Авторизація через нікнейм + аватар
- [x] Надсилання фото (Firebase Storage)
- [x] Голосові повідомлення + Waveform плеєр (CustomPainter)
- [x] Реакції на повідомлення (toggle emoji)
- [x] Reply + swipe-to-reply
- [x] Редагування та видалення повідомлень
- [x] Signal Dark UI (SignalColors + AppSizes)
- [x] Плаваюча овальна навігація
- [x] FCM Push (тільки учасникам чату ✅ FIXED)
- [x] Windows підтримка (HTTP fallback)
- [x] Shorebird OTA (у SettingsScreen)
- [x] Typing indicator з анімацією
- [x] Розділювачі дат + Scroll Date Overlay
- [x] Контекстне меню Signal-стиль
- [x] Пошук користувачів
- [x] Завантаження 50 повідомлень (request_history)

---

## ✅ ВИКОНАНИЙ РЕФАКТОРИНГ (v2.3.5)

| # | Задача | Результат |
|---|--------|-----------|
| Б1 | Push-фільтр по учасниках | ✅ where("username","in",recipients) + авто-видалення токенів |
| Б2 | Дублікат LoginScreen | ✅ Тільки login_screen.dart |
| Б3 | maxHttpBufferSize 60MB→10MB | ✅ 1e7 + pingTimeout |
| Б4 | Graceful shutdown | ✅ SIGTERM + SIGINT |
| Р1 | Розбито main.dart | ✅ 6 файлів у widgets/ |
| Р2 | ChatDateUtils | ✅ utils/date_utils.dart (імпорт as AppDate) |
| Р3 | SocketService | ✅ services/socket_service.dart singleton |
| Р4 | AppConfig + .env | ✅ config/app_config.dart + flutter_dotenv |
| Р5 | firebaseAvailable → AppConfig | ✅ AppConfig.firebaseAvailable |
| Р6 | voice_recorder.dart | ✅ Помилок немає |

---

## 🐛 ВІДОМІ ПРОБЛЕМИ (актуальні)

### 🔴 Критичні (Фаза 1):
1. **Немає пароля** — авторизація тільки по нікнейму
2. **Socket без JWT** — будь-хто може підключитись

### 🟡 Дрібні:
3. **Немає статусів ✓✓** — поле isRead є але завжди false
4. **Немає пагінації** — тільки останні 50 повідомлень
5. **Немає групових чатів**

---

## ⚠️ ВАЖЛИВІ НЮАНСИ (щоб не повторювати помилки)

```
1. DateUtils → ChatDateUtils
   Конфлікт з Flutter material.dart!
   import 'utils/date_utils.dart' as AppDate;
   AppDate.ChatDateUtils.formatTime(ts)

2. SettingsScreen — НЕ додавати leading: IconButton у AppBar
   Відкривається як вкладка IndexedStack → Navigator.pop = чорний екран

3. serverUrl — НЕ const (getter не може бути const)
   final String serverUrl = AppConfig.serverUrl; ← або напряму AppConfig.serverUrl

4. dotenv.load — ОБОВ'ЯЗКОВО try/catch
   try { await dotenv.load(fileName: '.env'); } catch (_) {}
   Без цього — чорний екран якщо .env відсутній

5. socket.emit — більше не використовувати напряму
   Тільки _socketSvc.методНазва()
   Виняток: _socketSvc.socket.emit('debug_log', ...) — тільки для debug

6. .env у pubspec.yaml assets — ОБОВ'ЯЗКОВО
   assets:
     - .env
     - shorebird.yaml
```

---

## 📱 ОСОБЛИВОСТІ ПЛАТФОРМ

```dart
if (!AppConfig.firebaseAvailable) {
  // Windows: HTTP /get_user_chats + Socket.IO request_history
  // _localMessages: List<Map> замість StreamBuilder
} else {
  // Android/iOS: Firestore StreamBuilder + FCM push + Shorebird OTA
}
```

---

## 📦 PUBSPEC — КЛЮЧОВІ ЗАЛЕЖНОСТІ

```yaml
socket_io_client: ^3.1.4
firebase_core: ^4.4.0
firebase_messaging: ^16.1.1
cloud_firestore: ^6.1.2
firebase_storage: ^12.1.2
flutter_dotenv: ^5.1.0
shorebird_code_push: ^2.0.5
image_picker: ^1.2.1
record: ^6.2.0
audioplayers: ^6.5.1
vibration: ^3.1.6
permission_handler: ^12.0.1
path_provider: ^2.1.1
shared_preferences: ^2.5.4
http: ^1.6.0

flutter:
  assets:
    - .env
    - shorebird.yaml
```

---

## 🗓 НАСТУПНІ КРОКИ (Фаза 1 — Безпека)

```
Встановити на сервері:
  npm install jsonwebtoken bcryptjs express-rate-limit helmet morgan joi

1. POST /auth — додати password, bcrypt.hash(password, 12)
2. Генерувати JWT token (7d) + refreshToken (30d)
3. Middleware verifyJWT для захищених ендпоінтів
4. POST /refresh для оновлення токена
5. Socket.IO auth: io.use((socket, next) => { jwt.verify(...) })
6. Flutter: поле пароля у LoginScreen + AuthService + Dio interceptor
7. Rate limiting: /auth 10req/15хв, /upload 30req/хв
```

---

## 💡 ЯК ВИКОРИСТОВУВАТИ ЦЕЙ ФАЙЛ

```
Новий чат → вставити CONTEXT.md → додати ТІЛЬКИ потрібний файл:

"додати JWT"              → server/index.js
"проблема у чаті"         → main.dart
"проблема навігація"      → home_screen.dart
"налаштування"            → settings_screen.dart
"пошук користувачів"      → search_screen.dart
"кольори / теми"          → theme.dart
"аудіо плеєр"             → audio_player_widget.dart
"сокет проблема"          → services/socket_service.dart
"дата/час"                → utils/date_utils.dart
"конфіг / env"            → config/app_config.dart
```