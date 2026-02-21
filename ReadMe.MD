# 💬 Messenger Y

> Кросплатформний месенджер у стилі Signal, побудований на Flutter + Node.js

![Version](https://img.shields.io/badge/version-2.4.0-2B5CE6?style=flat-square)
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
  <img src="screenshots/login.png" width="200"/>
</p>
-->

---

## ✨ Функції (v2.4.3)

### 🔐 Безпека (нове у v2.4.3)
- 🔑 **JWT авторизація** — access token (7д) + refresh token (30д)
- 🔒 **bcrypt паролі** — хешування з rounds=12
- 🛡️ **Rate limiting** — захист від brute-force та DoS
- ⛑️ **Helmet** — HTTP security headers
- ✅ **Joi валідація** — перевірка вхідних даних
- 🔐 **Socket.IO auth** — підключення тільки з валідним JWT
- 🌐 **Кирилиця у нікнеймах** — підтримка Unicode

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
- 🔍 **Пошук користувачів** — за нікнеймом

---

## 🏗 Архітектура

```
client/                          server/
├── lib/                         └── index.js  (v2.1.2)
│   ├── config/
│   │   └── app_config.dart      ← serverUrl з .env
│   ├── services/
│   │   ├── socket_service.dart  ← Socket.IO singleton + JWT auth
│   │   └── auth_service.dart    ← JWT login/logout/refresh ✅ NEW
│   ├── utils/
│   │   └── date_utils.dart      ← ChatDateUtils
│   ├── widgets/
│   │   ├── message_bubble.dart
│   │   ├── swipe_to_reply.dart
│   │   ├── typing_indicator.dart
│   │   ├── date_separator.dart
│   │   ├── reply_preview.dart
│   │   └── reaction_widgets.dart
│   ├── main.dart
│   ├── home_screen.dart
│   ├── login_screen.dart        ← нікнейм + пароль ✅ UPDATED
│   ├── search_screen.dart
│   ├── settings_screen.dart
│   ├── signal_context_menu.dart
│   ├── audio_player_widget.dart
│   ├── voice_recorder.dart
│   └── theme.dart
└── pubspec.yaml
```

**Стек:**

| Шар | Технологія |
|-----|-----------|
| Клієнт | Flutter 3.x |
| Сервер | Node.js 20 + Express 5 + Socket.IO 4.8 |
| База даних | Firebase Firestore |
| Сховище | Firebase Storage |
| Push | Firebase Cloud Messaging (FCM) |
| Auth | JWT + bcrypt ✅ |
| Real-time | Socket.IO rooms |
| OTA | Shorebird Code Push |

---

## 🚀 Швидкий старт

### Вимоги
- Flutter 3.x
- Node.js 20+
- Firebase проєкт (Firestore + Storage + FCM)

### Клієнт

```bash
# 1. Клонуй репо
git clone https://github.com/YOUR_USERNAME/messenger-y.git
cd messenger-y/client

# 2. Встанови залежності
flutter pub get

# 3. Створи .env файл
echo "SERVER_URL=https://your-server.onrender.com" > .env

# 4. Налаштуй Firebase
flutterfire configure --platforms=android,ios

# 5. Запусти
flutter run
```

### Сервер

```bash
cd server

# 1. Встанови залежності
npm install

# 2. Додай змінні оточення (або у Render → Environment)
# JWT_SECRET=ваш_секретний_ключ

# 3. Поклади serviceAccountKey.json у корінь server/

# 4. Запусти
node index.js
```

---

## ⚙️ Змінні оточення

### client/.env
```env
SERVER_URL=https://your-server.onrender.com
```

### server (Render → Environment Variables)
```env
PORT=3000
JWT_SECRET=your_very_long_random_secret_key_here
```

> ⚠️ **Обов'язково** встановити `JWT_SECRET` у продакшені! Без цього використовується небезпечний дефолтний ключ.

---

## 📦 Основні залежності

### Flutter (pubspec.yaml)
```yaml
socket_io_client: ^3.1.4
firebase_core: ^4.4.0
cloud_firestore: ^6.1.2
firebase_messaging: ^16.1.1
firebase_storage: ^12.1.2
flutter_dotenv: ^5.1.0
dio: ^5.4.0
audioplayers: ^6.5.1
record: ^6.2.0
image_picker: ^1.2.1
shorebird_code_push: ^2.0.5
shared_preferences: ^2.5.4
http: ^1.6.0
```

### Node.js (package.json)
```json
{
  "dependencies": {
    "bcryptjs": "^3.0.3",
    "cors": "^2.8.6",
    "express": "^5.2.1",
    "express-rate-limit": "^7.x",
    "firebase-admin": "^13.6.1",
    "helmet": "^8.x",
    "joi": "^17.x",
    "jsonwebtoken": "^9.x",
    "morgan": "^1.x",
    "multer": "^2.0.2",
    "socket.io": "^4.8.3"
  }
}
```

---

## 🌐 REST API

| Метод | Ендпоінт | Auth | Опис |
|-------|----------|------|------|
| POST | `/auth` | ❌ | Вхід / реєстрація → `{ token, refreshToken, user }` |
| POST | `/refresh` | ❌ | `{ refreshToken }` → `{ token }` |
| POST | `/upload` | ✅ JWT | Завантажити фото → `{ url }` |
| POST | `/upload-audio` | ✅ JWT | Завантажити аудіо → `{ url }` |
| GET | `/search_users` | ✅ JWT | `?q=&myUsername=` → users[] |
| POST | `/get_or_create_dm` | ✅ JWT | → chat |
| GET | `/get_user_chats` | ✅ JWT | `?username=` → chats[] (Windows) |
| GET | `/ping` | ❌ | Health check |

---

## 🗄 Структура Firestore

```
users/{username}
  ├── username: string
  ├── avatarUrl: string?
  ├── passwordHash: string   ← ✅ додано у v2.4.3
  └── createdAt: timestamp

chats/{chatId}
  ├── type: "dm"
  ├── participants: string[]
  └── lastMessage: { text, sender, timestamp, read }

chats/{chatId}/messages/{messageId}
  ├── text, sender, type
  ├── timestamp, read, edited
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
| Подія | Дані | Примітка |
|-------|------|----------|
| `join_chat` | chatId | |
| `send_message` | { chatId, text, type, replyTo?, audioUrl? } | sender береться з JWT |
| `delete_message` | { messageId, chatId } | |
| `edit_message` | { messageId, newText, chatId } | username береться з JWT |
| `add_reaction` | { messageId, emoji, chatId } | username береться з JWT |
| `typing` | { chatId } | username береться з JWT |
| `mark_read` | { chatId } | |
| `register_token` | { token } | username береться з JWT |
| `request_history` | chatId | |

### Сервер → Клієнт
| Подія | Дані |
|-------|------|
| `receive_message` | messageData |
| `load_history` | message[] |
| `message_deleted` | messageId |
| `message_edited` | { messageId, newText } |
| `reaction_updated` | { messageId, reactions } |
| `display_typing` | { username, chatId } |

---

## 📋 Changelog

### v2.4.3 — Лютий 2026 (поточна) — 🔒 ФАЗА 1: БЕЗПЕКА
- **JWT авторизація** — access (7д) + refresh (30д) токени
- **bcrypt паролі** — rounds=12, зберігаються як `passwordHash` у Firestore
- **Socket.IO auth middleware** — відхиляє підключення без валідного JWT
- **`sender` з JWT** — клієнт більше не може підробити ім'я відправника
- **Rate limiting** — `/auth` 10req/15хв, `/upload` 30req/хв, `/search` 60req/хв
- **Helmet** — HTTP security headers
- **Morgan** — request logging
- **Joi валідація** — username (3-20 символів, кирилиця підтримується), password (мін. 8 символів)
- **`trust proxy`** — виправлено для Render deployment
- **`POST /refresh`** — новий ендпоінт для оновлення токена
- **`AuthService`** (Flutter) — login, logout, getToken, refreshToken, isLoggedIn
- **JWT у всіх HTTP запитах** — upload, search, get_or_create_dm, get_user_chats
- **Плавна міграція** — старі акаунти без пароля отримують пароль при першому вході

### v2.3.5 — Лютий 2026
- Push-сповіщення тільки учасникам чату
- Автоматичне видалення невалідних FCM токенів
- `maxHttpBufferSize` 60MB → 10MB
- Graceful shutdown (SIGTERM/SIGINT)
- Рефакторинг `main.dart` → `widgets/`
- `SocketService` singleton
- `ChatDateUtils`, `AppConfig`, `flutter_dotenv`

### v2.3.0 — Січень 2026
- Голосові повідомлення + waveform плеєр (CustomPainter)

### v2.2.0
- Signal Dark UI (SignalColors + AppSizes)
- Плаваюча овальна навігація
- Контекстне меню SignalContextMenu

### v2.1.0
- Typing indicator, розділювачі дат, swipe-to-reply

### v2.0.0
- Реакції, редагування, видалення, Windows підтримка

### v1.0.0
- DM чати, авторизація, фото, push, Shorebird OTA

---

## 🗺 Роадмап

| Фаза | Статус | Задачі |
|------|--------|--------|
| 🔒 **Фаза 1** — Безпека | ✅ **ВИКОНАНО** | JWT, bcrypt, rate-limit, Socket auth |
| 💬 **Фаза 2** — Чат 2.0 | 🔜 Травень–Червень 2026 | Статуси ✓✓✓, онлайн, пагінація, файли, групи |
| 🎥 **Фаза 2+** | 🔜 | WebRTC дзвінки |
| 👥 **Фаза 3** — Соціальні | 📅 Липень–Серпень 2026 | Профілі, Сторіз |
| 🚀 **Фаза 4** — DevOps | 📅 Вересень–Жовтень 2026 | Redis, CI/CD, тести, Sentry |
| 🔐 **Фаза 5** — E2EE+ | 📅 Листопад 2026+ | Шифрування, монетизація |

Детальний план: [`Messenger_Y_Plan_v5.docx`](./docs/Messenger_Y_Plan_v5.docx)

---

## 📄 Ліцензія

MIT License

---

<p align="center">
  Зроблено з ❤️ на Flutter + Node.js
</p>