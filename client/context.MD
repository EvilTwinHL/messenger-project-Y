# 🗂 MESSENGER Y — PROJECT CONTEXT v2.4.3
> Вставляй цей файл першим повідомленням у новому чаті.
> Після цього додавай ТІЛЬКИ той файл, з яким зараз працюєш.

---

## 📦 СТЕК

| Шар | Технологія |
|-----|-----------|
| Клієнт | Flutter 3.x (Android, iOS, Windows) |
| Сервер | Node.js 20 + Express 5 + Socket.IO 4.8 (хостинг: Render) |
| БД | Firebase Firestore |
| Сховище | Firebase Storage |
| Push | FCM multicast (фільтр по учасниках ✅) |
| Auth | Нікнейм + пароль + JWT ✅ (Фаза 1 виконана) |
| OTA | Shorebird Code Push |
| Real-time | Socket.IO rooms + Firestore StreamBuilder |
| Config | flutter_dotenv (.env файл) |

---

## 🗂 СТРУКТУРА ФАЙЛІВ (актуальна v2.4.3)

```
client/
├── .env                           # SERVER_URL=https://pproject-y.onrender.com
├── pubspec.yaml
└── lib/
    ├── config/
    │   └── app_config.dart        # AppConfig.serverUrl (з .env) + AppConfig.firebaseAvailable
    ├── services/
    │   ├── socket_service.dart    # SocketService singleton — init({required String token})
    │   └── auth_service.dart      # AuthService — login, logout, getToken, refreshToken
    ├── utils/
    │   └── date_utils.dart        # ChatDateUtils: formatTime, dateLabel, parseDate, isSameDay
    ├── widgets/
    │   ├── message_bubble.dart
    │   ├── swipe_to_reply.dart
    │   ├── typing_indicator.dart
    │   ├── date_separator.dart
    │   ├── reply_preview.dart
    │   └── reaction_widgets.dart
    ├── main.dart                  # MyApp, main(), ChatScreen, AppColors, GlassBox
    ├── home_screen.dart           # HomeScreen + _OvalNavBar
    ├── login_screen.dart          # LoginScreen (нікнейм + пароль)
    ├── search_screen.dart         # SearchUserScreen
    ├── settings_screen.dart       # SettingsScreen — OTA, logout
    ├── signal_context_menu.dart   # SignalContextMenu overlay
    ├── audio_player_widget.dart   # AudioMessagePlayer + WaveformPainter
    ├── voice_recorder.dart        # VoiceRecorder widget
    └── theme.dart                 # SignalColors, AppSizes, AppTheme

server/
└── index.js                      # Express + Socket.IO + Firebase Admin (v2.1.2)
```

---

## ⚙️ ВАЖЛИВІ КОНСТАНТИ ТА ПРАВИЛА

```dart
// config/app_config.dart
class AppConfig {
  static String get serverUrl =>
    dotenv.env['SERVER_URL'] ?? 'https://pproject-y.onrender.com';
  static bool firebaseAvailable = false;
}

// services/auth_service.dart — НОВИЙ ФАЙЛ (Фаза 1)
// AuthService.login(username, password, avatarUrl?)  → Map токени + юзер
// AuthService.getToken()       → String? (JWT access token)
// AuthService.getRefreshToken() → String?
// AuthService.refreshToken()   → String? (оновлює access token)
// AuthService.logout()         → очищає всі збережені дані
// AuthService.isLoggedIn()     → bool
// AuthService.getSavedUsername() → String?

// services/socket_service.dart — ОНОВЛЕНО (Фаза 1)
// init() тепер ВИМАГАЄ токен:
// _socketSvc.init(token: token ?? '');
// Виклик у main.dart initSocket():
//   final token = await AuthService.getToken();
//   _socketSvc.init(token: token ?? '');

// date_utils.dart — клас називається ChatDateUtils (НЕ DateUtils!)
// Конфлікт з Flutter material.dart!
// Імпорт: import 'utils/date_utils.dart' as AppDate;
// Виклик: AppDate.ChatDateUtils.formatTime(ts)
```

```javascript
// server/index.js v2.4.3 — ключові налаштування
const JWT_SECRET = process.env.JWT_SECRET || "change_me_in_production_please";

// ОБОВ'ЯЗКОВО встановити JWT_SECRET у Render → Environment Variables!

app.set('trust proxy', 1); // Render використовує proxy — без цього rate-limit не працює

const io = new Server(server, {
  cors: { origin: "*" },
  maxHttpBufferSize: 1e7,
  pingTimeout: 60000,
  pingInterval: 25000,
});

// Socket.IO auth middleware — відхиляє підключення без токена
io.use((socket, next) => {
  const token = socket.handshake.auth?.token;
  jwt.verify(token, JWT_SECRET); // кидає помилку якщо невалідний
  socket.username = decoded.username; // username береться з JWT, не від клієнта!
});

// sender у send_message — береться з socket.username (JWT), не з data.sender!
// Це захищає від підробки імені відправника.
```

---

## 🔐 АВТОРИЗАЦІЯ (Фаза 1 — виконано)

```
POST /auth  { username, password, avatarUrl? }
  → { status: "created"|"found", token, refreshToken, user }

POST /refresh  { refreshToken }
  → { token }  (новий access token)

JWT: access token — 7 днів, refresh token — 30 днів
bcrypt rounds: 12

Захищені ендпоінти (verifyJWT middleware):
  POST /upload
  POST /upload-audio
  GET  /search_users
  POST /get_or_create_dm
  GET  /get_user_chats

Flutter — передача токена:
  HTTP:   headers: {'Authorization': 'Bearer $token'}
  Socket: IO.OptionBuilder().setAuth({'token': token})
```

---

## ⏱️ RATE LIMITING (Фаза 1 — виконано)

```
POST /auth        → 10 req / 15 хвилин
POST /upload      → 30 req / хвилину
POST /upload-audio → 30 req / хвилину
GET  /search_users → 60 req / хвилину
```

---

## 🎨 ДИЗАЙН-СИСТЕМА (theme.dart)

```dart
SignalColors.primary        // #2B5CE6
SignalColors.appBackground  // #111113
SignalColors.surface        // #1A1B1D
SignalColors.elevated       // #252528
SignalColors.outgoing       // #2B5CE6
SignalColors.incoming       // #2C2C2E
SignalColors.textPrimary    // #FFFFFF
SignalColors.textSecondary  // #8E8E9A
SignalColors.danger         // червоний
SignalColors.online         // зелений

AppSizes.navBarHeight       // 72
AppSizes.bubbleRadius       // 18
AppSizes.avatarRadiusMedium // 27
AppSizes.avatarRadiusLarge  // 36
```

---

## 🔥 FIRESTORE СТРУКТУРА

```
users/{username}
  username, avatarUrl, createdAt, passwordHash ✅ (Фаза 1)
  [ПЛАН Ф2] bio, online, lastSeen

chats/{chatId}
  type: "dm"
  participants: [username1, username2]
  lastMessage: { text, sender, timestamp, read }

chats/{chatId}/messages/{messageId}
  text, sender, senderAvatar, type
  timestamp, read, edited, editedAt
  replyTo: { id, text, sender }
  reactions: { "❤️": ["user1"] }
  audioUrl, audioDuration
  [ПЛАН Ф2] status: "sent"|"delivered"|"read"

fcm_tokens/{token}
  username, updatedAt  ← невалідні видаляються автоматично ✅
```

---

## 🔌 SOCKET.IO — SocketService методи

```dart
// ТІЛЬКИ через SocketService!
final _socketSvc = SocketService();

_socketSvc.init(token: token)   // ← ОБОВ'ЯЗКОВО передавати JWT токен
_socketSvc.connect() / disconnect()
_socketSvc.joinChat(chatId)
_socketSvc.leaveChat(chatId)
_socketSvc.sendMessage(data)    // sender береться з JWT на сервері
_socketSvc.deleteMessage(msgId, chatId)
_socketSvc.editMessage(msgId, text, user, chatId)
_socketSvc.addReaction(msgId, emoji, user, chatId)
_socketSvc.emitTyping(username, chatId)
_socketSvc.markRead(chatId, username)
_socketSvc.registerToken(token, username)
_socketSvc.requestHistory(chatId)
_socketSvc.on(event, handler)
_socketSvc.isConnected
_socketSvc.dispose()
```

---

## 🌐 REST API

| Метод | Ендпоінт | Auth | Опис |
|-------|----------|------|------|
| POST | `/auth` | ❌ | { username, password, avatarUrl? } → { token, refreshToken, user } |
| POST | `/refresh` | ❌ | { refreshToken } → { token } |
| POST | `/upload` | ✅ JWT | фото → { url } |
| POST | `/upload-audio` | ✅ JWT | аудіо → { url } |
| GET | `/search_users?q=&myUsername=` | ✅ JWT | пошук |
| POST | `/get_or_create_dm` | ✅ JWT | → chat |
| GET | `/get_user_chats?username=` | ✅ JWT | список чатів (Windows) |
| GET | `/ping` | ❌ | health check |

---

## ✅ ЩО РЕАЛІЗОВАНО (19 функцій)

- [x] Приватні чати (DM) — Firestore + Socket.IO
- [x] Авторизація — нікнейм + **пароль (bcrypt)** + **JWT** ✅ Фаза 1
- [x] **Rate limiting + Helmet + Morgan + Joi валідація** ✅ Фаза 1
- [x] **Socket.IO auth middleware (JWT)** ✅ Фаза 1
- [x] Надсилання фото (Firebase Storage)
- [x] Голосові повідомлення + Waveform плеєр
- [x] Реакції на повідомлення (toggle emoji)
- [x] Reply + swipe-to-reply
- [x] Редагування та видалення повідомлень
- [x] Signal Dark UI (SignalColors + AppSizes)
- [x] Плаваюча овальна навігація
- [x] FCM Push (тільки учасникам ✅)
- [x] Windows підтримка (HTTP fallback)
- [x] Shorebird OTA
- [x] Typing indicator
- [x] Розділювачі дат + Scroll Date Overlay
- [x] Контекстне меню Signal-стиль
- [x] Пошук користувачів
- [x] Завантаження 50 повідомлень

---

## ✅ ВИКОНАНИЙ РЕФАКТОРИНГ І ФАЗИ

| # | Задача | Версія |
|---|--------|--------|
| Б1 | Push-фільтр по учасниках | v2.3.5 |
| Б2 | Дублікат LoginScreen | v2.3.5 |
| Б3 | maxHttpBufferSize 60MB→10MB | v2.3.5 |
| Б4 | Graceful shutdown | v2.3.5 |
| Р1–Р6 | Рефакторинг main.dart, utils, services, config | v2.3.5 |
| Ф1-1 | bcrypt паролі у /auth | v2.4.3 |
| Ф1-2 | JWT access + refresh токени | v2.4.3 |
| Ф1-3 | verifyJWT middleware | v2.4.3 |
| Ф1-4 | Socket.IO JWT auth | v2.4.3 |
| Ф1-5 | Rate limiting (auth/upload/search) | v2.4.3 |
| Ф1-6 | Helmet + Morgan + Joi + trust proxy | v2.4.3 |
| Ф1-7 | AuthService (Flutter) | v2.4.3 |
| Ф1-8 | JWT у всіх HTTP запитах | v2.4.3 |
| Ф1-9 | Кирилиця у нікнеймах | v2.4.3 |

---

## 🐛 ВІДОМІ ПРОБЛЕМИ (актуальні)

### 🟡 Дрібні:
1. **Немає статусів ✓✓** — поле read є але логіка не реалізована
2. **Немає пагінації** — тільки останні 50 повідомлень
3. **Немає групових чатів**

---

## ⚠️ ВАЖЛИВІ НЮАНСИ

```
1. DateUtils → ChatDateUtils
   import 'utils/date_utils.dart' as AppDate;
   AppDate.ChatDateUtils.formatTime(ts)

2. SettingsScreen — НЕ додавати leading: IconButton у AppBar
   Відкривається як вкладка IndexedStack → Navigator.pop = чорний екран

3. serverUrl — НЕ const (getter не може бути const)

4. dotenv.load — ОБОВ'ЯЗКОВО try/catch

5. socket.emit — тільки через _socketSvc.методНазва()

6. SocketService.init() — ОБОВ'ЯЗКОВО передавати token:
   final token = await AuthService.getToken();
   _socketSvc.init(token: token ?? '');

7. HTTP запити до захищених ендпоінтів — ОБОВ'ЯЗКОВО заголовок:
   headers: {'Authorization': 'Bearer ${token ?? ''}'}

8. JWT_SECRET — встановити у Render → Environment Variables!
   Не залишати дефолтний "change_me_in_production_please"

9. sender у Socket повідомленнях береться з JWT (socket.username)
   НЕ передавати sender від клієнта — ігнорується сервером
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
dio: ^5.4.0                  # ← ДОДАНО у Фазі 1
shorebird_code_push: ^2.0.5
image_picker: ^1.2.1
record: ^6.2.0
audioplayers: ^6.5.1
vibration: ^3.1.6
permission_handler: ^12.0.1
path_provider: ^2.1.1
shared_preferences: ^2.5.4
http: ^1.6.0
```

## SERVER — ЗАЛЕЖНОСТІ (package.json)

```json
"bcryptjs": "^3.0.3",
"cors": "^2.8.6",
"express": "^5.2.1",
"firebase-admin": "^13.6.1",
"helmet": "^8.x",
"joi": "^17.x",
"jsonwebtoken": "^9.x",
"morgan": "^1.x",
"express-rate-limit": "^7.x",
"multer": "^2.0.2",
"socket.io": "^4.8.3"
```

---

## 💡 ЯК ВИКОРИСТОВУВАТИ ЦЕЙ ФАЙЛ

```
Новий чат → вставити CONTEXT.md → додати ТІЛЬКИ потрібний файл:

"JWT / авторизація"       → services/auth_service.dart
"додати JWT на сервері"   → server/index.js
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