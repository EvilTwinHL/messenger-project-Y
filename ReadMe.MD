# 💬 Messenger Y

> Кросплатформний месенджер у стилі Signal, побудований на Flutter + Node.js

![Version](https://img.shields.io/badge/version-2.6.8-2B5CE6?style=flat-square)
![Flutter](https://img.shields.io/badge/Flutter-3.x-54C5F8?style=flat-square&logo=flutter)
![Node.js](https://img.shields.io/badge/Node.js-20.x-339933?style=flat-square&logo=node.js)
![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%2B%20Storage-FFCA28?style=flat-square&logo=firebase)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows-lightgrey?style=flat-square)
![Security](https://img.shields.io/badge/Auth-JWT%20%2B%20bcrypt-green?style=flat-square)

---

## 📱 Скріншоти

> *(Додай скріншоти у папку `/screenshots` та розкоментуй нижче)*

<!--
<p align="center">
  <img src="screenshots/chat.png" width="200"/>
  <img src="screenshots/home.png" width="200"/>
  <img src="screenshots/account.png" width="200"/>
</p>
-->

---

## ✨ Функції (v2.6.8)

### 🔐 Безпека (v2.4.3)
- 🔑 **JWT авторизація** — access token (7д) + refresh token (30д)
- 🔒 **bcrypt паролі** — хешування з rounds=12
- 🛡️ **Rate limiting** — захист від brute-force та DoS
- ⛑️ **Helmet** — HTTP security headers
- ✅ **Joi валідація** — перевірка вхідних даних
- 🔐 **Socket.IO auth** — підключення тільки з валідним JWT

### 👤 Профіль та акаунт (нове у v2.6.0)
- 🪪 **DisplayName vs Username** — displayName (будь-яка мова/кирилиця, видимий псевдонім), username (Latin-only, для входу і пошуку)
- 📱 **Account Tab (Telegram-style)** — аватар з camera badge, статус онлайн, інфо-картка
- 📞 **Телефон та день народження** — збереження в Firestore + видимість
- 🟢 **Онлайн-статус** — toggle "показувати/не показувати"
- 🔄 **POST /update_profile** — оновлення всіх полів профілю

### 🔑 Авторизація (нове у v2.6.0)
- **Login/Register розділено** — TabBar з двома вкладками в одному екрані
- **Suggested accounts** — при запуску шукає акаунти по збереженому номеру

### ✓ Статуси повідомлень (нове у v2.6.3–2.6.8)
- **✓ sent** — відправлено на сервер (1 кружок, сірий)
- **✓✓ delivered** — доставлено (2 кружки, сірий контур + синя заливка)
- **✓✓ read** — прочитано (2 кружки, синій контур + галочки)
- **Real-time** — оновлення без перезавантаження чату
- **Signal-style CustomPainter** — кружечки з галочками замість Material icons

### Повідомлення
- 💬 **Приватні чати (DM)** — реал-тайм через Firestore + Socket.IO
- 📷 **Надсилання фото** — завантаження у Firebase Storage
- 🎤 **Голосові повідомлення** — запис AAC + Signal-стиль waveform плеєр
- ↩️ **Reply** — відповідь на конкретне повідомлення + swipe-to-reply
- ✏️ **Редагування та видалення** — з позначкою "edited"
- 😊 **Реакції** — emoji toggle
- ⌨️ **Typing indicator** — анімація трьох крапок

### UI / UX
- 🎨 **Signal Dark UI** — власна дизайн-система `SignalColors` + `AppSizes`
- 🗺 **Плаваюча навігація** — овальна таблетка у Telegram-стилі
- 📅 **Розділювачі дат** + Scroll Date Overlay
- 📋 **Контекстне меню** — blur overlay з реакціями та діями

### Технічне
- 🔔 **FCM Push Notifications** — тільки учасникам чату
- 🪟 **Windows підтримка** — HTTP fallback + Socket.IO
- 🚀 **Shorebird OTA** — оновлення без перевидання у Store
- 🔍 **Пошук користувачів** — за username або displayName

---

## 🏗 Архітектура

```
client/                          server/
├── lib/                         └── index.js  (v2.6.8)
│   ├── config/
│   │   └── app_config.dart
│   ├── services/
│   │   ├── socket_service.dart
│   │   └── auth_service.dart    ← saveUser з displayName ✅ v2.6.0
│   ├── utils/
│   │   └── date_utils.dart
│   ├── widgets/
│   │   ├── message_bubble.dart  ← status + Signal-style icons ✅ v2.6.3
│   │   ├── swipe_to_reply.dart
│   │   ├── typing_indicator.dart
│   │   ├── date_separator.dart
│   │   ├── reply_preview.dart
│   │   └── reaction_widgets.dart
│   ├── main.dart                ← _messageStatuses cache ✅ v2.6.5
│   ├── home_screen.dart         ← AccountTab Telegram-style ✅ v2.6.0
│   ├── login_screen.dart        ← TabBar Login/Register ✅ v2.6.0
│   ├── search_screen.dart
│   ├── settings_screen.dart     ← без секції профілю ✅ v2.6.0
│   ├── signal_context_menu.dart
│   ├── audio_player_widget.dart
│   ├── voice_recorder.dart
│   └── theme.dart
└── pubspec.yaml
```

---

## 🚀 Швидкий старт

### Клієнт

```bash
git clone https://github.com/YOUR_USERNAME/messenger-y.git
cd messenger-y/client
flutter pub get
echo "SERVER_URL=https://your-server.onrender.com" > .env
flutterfire configure --platforms=android,ios
flutter run
```

### Сервер

```bash
cd server
npm install
# Встанови JWT_SECRET у Render → Environment Variables
node index.js
```

---

## ⚙️ Змінні оточення

```env
# client/.env
SERVER_URL=https://your-server.onrender.com

# server (Render → Environment Variables)
PORT=3000
JWT_SECRET=your_very_long_random_secret_key_here
```

---

## 🌐 REST API

| Метод | Ендпоінт | Auth | Опис |
|-------|----------|------|------|
| POST | `/auth` | ❌ | { username, password, displayName? } → { token, refreshToken, user } |
| POST | `/refresh` | ❌ | { refreshToken } → { token } |
| POST | `/upload` | ✅ | фото → { url } |
| POST | `/upload-audio` | ✅ | аудіо → { url } |
| GET | `/search_users` | ✅ | `?q=&myUsername=` → users[] |
| POST | `/get_or_create_dm` | ✅ | → chat |
| GET | `/get_user_chats` | ✅ | `?username=` → chats[] (Windows) |
| POST | `/update_profile` | ✅ | displayName, phone, birthday, onlineVisible... |
| GET | `/accounts_by_phone` | ❌ | `?phone=` → accounts[] (suggested login) |
| GET | `/ping` | ❌ | health check |

---

## 🗄 Структура Firestore

```
users/{username}
  ├── username: string          ← Latin-only, immutable, для входу/пошуку
  ├── displayName: string       ← будь-яка мова, видимий псевдонім ✅ NEW
  ├── avatarUrl: string?
  ├── passwordHash: string
  ├── phone: string?            ✅ NEW
  ├── birthday: string?         ✅ NEW (ISO date)
  ├── birthdayVisible: bool     ✅ NEW
  ├── onlineVisible: bool       ✅ NEW
  └── createdAt: timestamp

chats/{chatId}
  ├── type: "dm"
  ├── participants: string[]
  ├── participantNames: Map     ✅ NEW { username: displayName }
  └── lastMessage: { text, sender, timestamp, read }

chats/{chatId}/messages/{messageId}
  ├── text, sender, type
  ├── timestamp, read, edited
  ├── status: "sent"|"delivered"|"read"  ✅ NEW
  ├── replyTo: { id, text, sender }?
  ├── reactions: { "❤️": ["user1"] }?
  ├── audioUrl, audioDuration?
  └── imageUrl?

fcm_tokens/{token}
  ├── username: string
  └── updatedAt: timestamp
```

---

## 🔌 Socket.IO API

### Клієнт → Сервер
| Подія | Дані |
|-------|------|
| `join_chat` | chatId |
| `send_message` | { chatId, text, type, replyTo?, audioUrl? } |
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

## 📋 Changelog

### v2.6.8 — Лютий 2026 — ✓✓ Статуси (real-time фікс)
- **mark_read при receive_message** — якщо чат відкритий і приходить чуже повідомлення → одразу read
- **delivered check** — перевірка всіх `io.sockets.sockets` (не тільки кімнати чату)
- **_messageStatuses cache** — локальний Map для миттєвого UI оновлення без Firestore latency

### v2.6.5 — Лютий 2026 — ✓✓ Статуси (архітектура)
- **_messageStatuses** — `Map<String, String>` кеш у ChatScreen
- Заповнюється з `load_history` і `receive_message`
- Має пріоритет над полем `status` з Firestore

### v2.6.3 — Лютий 2026 — Signal-style іконки статусів
- **CustomPainter** замість Material Icons
- sent = 1 кружок сірий; delivered = 2 кружки сірі+синя заливка; read = 2 кружки сині
- Обидва кружочки мають галочку (delivered і read)
- `status: String?` замінює `isRead: bool` у MessageBubble

### v2.6.0 — Лютий 2026 — 👤 Профіль + Auth UX
- **DisplayName vs Username** — displayName (кирилиця, змінний), username (Latin, незмінний)
- **AccountTab (Telegram-style)** — повний перегляд і редагування профілю
- **Login/Register** — розділені в TabBar одного екрану
- **Suggested accounts** — GET /accounts_by_phone при запуску
- **POST /update_profile** — оновлення phone, birthday, onlineVisible, displayName
- **Settings** — прибрано секцію профілю (перенесено в AccountTab)

### v2.4.3 — Лютий 2026 — 🔒 Фаза 1: Безпека
- JWT авторизація (access 7д + refresh 30д)
- bcrypt паролі (rounds=12)
- Socket.IO auth middleware
- Rate limiting, Helmet, Morgan, Joi валідація

### v2.3.5 — Лютий 2026
- Push-сповіщення тільки учасникам чату
- maxHttpBufferSize, Graceful shutdown
- Рефакторинг main.dart → widgets/

### v2.3.0 — Січень 2026
- Голосові повідомлення + waveform плеєр

### v2.2.0
- Signal Dark UI, плаваюча навігація, контекстне меню

### v2.0.0
- Реакції, редагування, видалення, Windows підтримка

### v1.0.0
- DM чати, авторизація, фото, push, Shorebird OTA

---

## 🗺 Роадмап

| Фаза | Статус | Задачі |
|------|--------|--------|
| 🔒 **Фаза 1** — Безпека | ✅ **ВИКОНАНО** | JWT, bcrypt, rate-limit, Socket auth |
| 👤 **Профіль** | ✅ **ВИКОНАНО** | AccountTab, displayName, phone, birthday |
| ✓✓ **Статуси** | ✅ **ВИКОНАНО** | sent/delivered/read, real-time, Signal-style |
| 🟢 **Онлайн-статус** | 🔄 **В роботі** | "онлайн" / "був о HH:MM" в AppBar чату |
| 📜 **Пагінація** | 🔜 | Infinite scroll, load older messages |
| 📎 **Файли** | 🔜 | PDF, DOCX, ZIP sharing |
| 👥 **Групові чати** | 🔜 | Групи, адміни, запрошення |
| 📹 **WebRTC** | 🔜 | Відео/аудіо дзвінки |
| 👥 **Фаза 3** — Соціальні | 📅 | Профілі, Сторіз |
| 🚀 **Фаза 4** — DevOps | 📅 | Redis, CI/CD, тести, Sentry |
| 🔐 **Фаза 5** — E2EE | 📅 | Шифрування, монетизація |

---

## 📄 Ліцензія

MIT License

---

<p align="center">
  Зроблено з ❤️ на Flutter + Node.js
</p>