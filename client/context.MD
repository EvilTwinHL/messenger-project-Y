# 🗂 MESSENGER Y — PROJECT CONTEXT v2.6.8
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

## 🗂 СТРУКТУРА ФАЙЛІВ (актуальна v2.6.8)

```
client/
├── .env                           # SERVER_URL=https://pproject-y.onrender.com
├── pubspec.yaml
└── lib/
    ├── config/
    │   └── app_config.dart        # AppConfig.serverUrl + AppConfig.firebaseAvailable
    ├── services/
    │   ├── socket_service.dart    # SocketService singleton
    │   └── auth_service.dart      # login, logout, getToken, saveUser, getSavedDisplayName
    ├── utils/
    │   └── date_utils.dart        # ChatDateUtils
    ├── widgets/
    │   ├── message_bubble.dart    # status: "sent"|"delivered"|"read" + Signal-style іконки
    │   ├── swipe_to_reply.dart
    │   ├── typing_indicator.dart
    │   ├── date_separator.dart
    │   ├── reply_preview.dart
    │   └── reaction_widgets.dart
    ├── main.dart                  # ChatScreen + _messageStatuses cache
    ├── home_screen.dart           # HomeScreen + AccountTab (Telegram-style) + _OvalNavBar
    ├── login_screen.dart          # LoginScreen (TabBar: Увійти / Зареєструватись)
    ├── search_screen.dart
    ├── settings_screen.dart       # БЕЗ секції профілю (перенесено в AccountTab)
    ├── signal_context_menu.dart
    ├── audio_player_widget.dart
    ├── voice_recorder.dart
    └── theme.dart

server/
└── index.js                      # Express + Socket.IO + Firebase Admin (v2.6.8)
```

---

## ⚙️ ВАЖЛИВІ КОНСТАНТИ ТА ПРАВИЛА

```dart
// auth_service.dart — ОНОВЛЕНО (v2.6.0)
// AuthService.login(username, password, displayName?)  → Map токени + юзер
// AuthService.saveUser(username, displayName, avatarUrl?) → зберігає локально
// AuthService.getSavedDisplayName() → String?
// AuthService.getSavedUsername()    → String?
// AuthService.getSavedAvatarUrl()   → String?
// AuthService.getToken()            → String?
// AuthService.logout()              → очищає всі збережені дані

// home_screen.dart — AccountTab (v2.6.0)
// Акаунт-таб Telegram-стиль:
//   - Аватар з camera badge (редагування)
//   - DisplayName + @username + онлайн-статус (клікабельний)
//   - 3 кнопки: Фото / Редагувати / Налаштування
//   - Інфо-картка: phone, @username (copy), birthday + visibility
//   - Кнопка Вийти
//   - Всі зміни → _pushProfileToServer() → POST /update_profile

// login_screen.dart — Split (v2.6.0)
// TabBar з двома вкладками:
//   "Увійти" → username + password
//   "Зареєструватись" → username + displayName (optional) + password + confirm
// При запуску: якщо є збережений phone → GET /accounts_by_phone
//   → suggestedAccounts → _AccountPickerSheet (bottomSheet)

// message_bubble.dart — Статуси (v2.6.3)
// status: String? ("sent" | "delivered" | "read") — замінює isRead: bool
// _StatusIcon → _SignalStatus → _StatusPainter (CustomPainter):
//   sent      = 1 кружок, сірий контур + синя заливка (#2B5CE6) + сіра галочка
//   delivered = 2 кружки, сірий контур + синя заливка + сірі галочки (обидва)
//   read      = 2 кружки, синій контур (#2B5CE6) + сіра заливка + сині галочки

// main.dart — _messageStatuses (v2.6.5)
// Map<String, String> _messageStatuses — локальний кеш статусів
// Оновлюється через socket 'message_status_update' для ОБОХ режимів
// Перекриває статус з Firestore/localMessages для миттєвого відображення
// Заповнюється при load_history і receive_message
// mark_read емітується при onConnect І при receive_message від іншого
```

```javascript
// server/index.js v2.6.8 — нові ендпоінти та Socket події

// POST /update_profile (verifyJWT) — оновлення профілю
// Поля: displayName, avatarUrl, phone, birthday, birthdayVisible, onlineVisible

// GET /accounts_by_phone?phone=... (без auth) — акаунти по телефону
// Повертає до 5 акаунтів: { username, displayName, avatarUrl }

// Socket: send_message → status: 'sent' → миттєва перевірка delivered
//   Перевіряє всі io.sockets.sockets (не тільки кімнату!)
//   Якщо отримувач онлайн (будь-який сокет) → одразу delivered

// Socket: join_chat → batch update sent→delivered для чужих повідомлень
//   Одиночні запити (не compound) → фільтр в JS

// Socket: mark_read → batch update sent|delivered→read для чужих повідомлень
//   Два окремих запити (sent і delivered) → фільтр в JS → emit message_status_update

// Socket emit: 'message_status_update' → { messageId, status }
```

---

## 🔐 АВТОРИЗАЦІЯ (Фаза 1 — виконано)

```
POST /auth  { username, password, displayName?, avatarUrl? }
  → { status: "created"|"found", token, refreshToken, user }

POST /refresh  { refreshToken }
  → { token }

JWT: access token — 7 днів, refresh token — 30 днів
bcrypt rounds: 12

Захищені ендпоінти (verifyJWT):
  POST /upload, POST /upload-audio
  GET  /search_users
  POST /get_or_create_dm, GET /get_user_chats
  POST /update_profile ✅ NEW v2.6.0
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
```

---

## 🔥 FIRESTORE СТРУКТУРА

```
users/{username}
  username, displayName ✅ NEW v2.6.0
  avatarUrl, passwordHash, createdAt
  phone, birthday, birthdayVisible, onlineVisible ✅ NEW v2.6.0
  [ПЛАН Ф2] online, lastSeen

chats/{chatId}
  type: "dm"
  participants: [username1, username2]
  participantNames: { username1: displayName1 } ✅ NEW v2.6.0
  lastMessage: { text, sender, timestamp, read }

chats/{chatId}/messages/{messageId}
  text, sender, senderAvatar, type
  timestamp, read, edited, editedAt
  status: "sent"|"delivered"|"read" ✅ NEW v2.6.3
  replyTo: { id, text, sender }
  reactions: { "❤️": ["user1"] }
  audioUrl, audioDuration, imageUrl

fcm_tokens/{token}
  username, updatedAt
```

---

## 🔌 SOCKET.IO — Події

### Клієнт → Сервер
| Подія | Дані |
|-------|------|
| `join_chat` | chatId → auto delivered update |
| `send_message` | { chatId, text, type, ... } |
| `mark_read` | { chatId, readerUsername } |
| `delete_message` | { messageId, chatId } |
| `edit_message` | { messageId, newText, chatId } |
| `add_reaction` | { messageId, emoji, chatId } |
| `typing` | { chatId } |
| `register_token` | { token } |
| `request_history` | chatId |

### Сервер → Клієнт
| Подія | Дані |
|-------|------|
| `receive_message` | messageData (з status: 'sent') |
| `message_status_update` | { messageId, status } ✅ NEW |
| `load_history` | message[] |
| `message_deleted` | messageId |
| `message_edited` | { messageId, newText } |
| `reaction_updated` | { messageId, reactions } |
| `display_typing` | { username, chatId } |

---

## 🌐 REST API

| Метод | Ендпоінт | Auth | Опис |
|-------|----------|------|------|
| POST | `/auth` | ❌ | { username, password, displayName? } → { token, refreshToken, user } |
| POST | `/refresh` | ❌ | { refreshToken } → { token } |
| POST | `/upload` | ✅ | фото → { url } |
| POST | `/upload-audio` | ✅ | аудіо → { url } |
| GET | `/search_users?q=&myUsername=` | ✅ | пошук |
| POST | `/get_or_create_dm` | ✅ | → chat |
| GET | `/get_user_chats?username=` | ✅ | список чатів (Windows) |
| POST | `/update_profile` | ✅ | displayName, phone, birthday... ✅ NEW |
| GET | `/accounts_by_phone?phone=` | ❌ | акаунти по телефону ✅ NEW |
| GET | `/ping` | ❌ | health check |

---

## ✅ ЩО РЕАЛІЗОВАНО (v2.6.8)

- [x] Приватні чати (DM) — Firestore + Socket.IO
- [x] **displayName vs username** — displayName (будь-яка мова), username (Latin, immutable) ✅ NEW
- [x] Авторизація — username + password (bcrypt) + JWT
- [x] **Login/Register розділено** — TabBar з двома вкладками ✅ NEW
- [x] **AccountTab (Telegram-style)** — аватар, статус, phone, birthday, edit ✅ NEW
- [x] **Акаунти по телефону** — suggestedAccounts при запуску ✅ NEW
- [x] **POST /update_profile** — phone, birthday, onlineVisible, displayName ✅ NEW
- [x] **Статуси повідомлень** ✓/✓✓/✓✓синій — sent/delivered/read ✅ NEW
- [x] **Signal-style іконки статусів** — CustomPainter з кружечками і галочками ✅ NEW
- [x] **Real-time статуси** — _messageStatuses cache + mark_read on receive ✅ NEW
- [x] Rate limiting + Helmet + Morgan + Joi валідація
- [x] Socket.IO auth middleware (JWT)
- [x] Надсилання фото (Firebase Storage)
- [x] Голосові повідомлення + Waveform плеєр
- [x] Реакції на повідомлення
- [x] Reply + swipe-to-reply
- [x] Редагування та видалення повідомлень
- [x] Signal Dark UI (SignalColors + AppSizes)
- [x] Плаваюча овальна навігація
- [x] FCM Push (тільки учасникам)
- [x] Windows підтримка (HTTP fallback)
- [x] Shorebird OTA
- [x] Typing indicator
- [x] Розділювачі дат + Scroll Date Overlay
- [x] Контекстне меню Signal-стиль
- [x] Пошук користувачів

---

## 🐛 ВІДОМІ ПРОБЛЕМИ / НАСТУПНІ КРОКИ

- [ ] Онлайн-статус у AppBar чату ("онлайн" / "був о HH:MM") — **зараз хардкод**
- [ ] Пагінація повідомлень — тільки останні 50
- [ ] Групові чати
- [ ] Шарінг файлів (PDF, DOCX, ZIP)
- [ ] WebRTC дзвінки

---

## ⚠️ ВАЖЛИВІ НЮАНСИ

```
1. DateUtils → ChatDateUtils (конфлікт з Flutter material.dart)
   import 'utils/date_utils.dart';

2. SettingsScreen — НЕ додавати leading: IconButton у AppBar
   (відкривається як вкладка IndexedStack)

3. SocketService.init() — ОБОВ'ЯЗКОВО передавати token:
   final token = await AuthService.getToken();
   _socketSvc.init(token: token ?? '');

4. HTTP запити до захищених ендпоінтів:
   headers: {'Authorization': 'Bearer ${token ?? ''}'}

5. sender у Socket повідомленнях береться з JWT (socket.username)

6. message_bubble.dart — НЕ використовувати isRead: bool (застарілий)
   Використовувати status: String? ("sent"|"delivered"|"read")

7. Статуси — Firestore compound query вимагає index!
   Використовуємо два окремих запити + фільтр в JS

8. _messageStatuses[msgId] МАЄ пріоритет над msg['status'] з Firestore
```

---

## 💡 ЯК ВИКОРИСТОВУВАТИ ЦЕЙ ФАЙЛ

```
Новий чат → вставити CONTEXT.md → додати ТІЛЬКИ потрібний файл:

"профіль / акаунт"        → home_screen.dart
"логін / реєстрація"      → login_screen.dart
"статуси повідомлень"     → widgets/message_bubble.dart + main.dart
"проблема у чаті"         → main.dart
"сервер / API"            → server/index.js
"навігація / HomeScreen"  → home_screen.dart
"налаштування"            → settings_screen.dart
"авторизація / JWT"       → services/auth_service.dart
"пошук"                   → search_screen.dart
"кольори / теми"          → theme.dart
"аудіо плеєр"             → audio_player_widget.dart
"сокет"                   → services/socket_service.dart
"дата/час"                → utils/date_utils.dart
```