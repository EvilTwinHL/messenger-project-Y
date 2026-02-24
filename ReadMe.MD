# 💬 Messenger Y

> Кросплатформний месенджер у стилі Signal, побудований на Flutter + Node.js

![Version](https://img.shields.io/badge/version-2.9.7-2B5CE6?style=flat-square)
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

## ✨ Функції (v2.9.7)

### 🔴 Лічильник непрочитаних (нове у v2.9.7)
- **Badge на аватарі** — червоне коло з числом на кожному чаті в HomeScreen
- **Real-time** — оновлюється через Firestore StreamBuilder миттєво
- **Автоматичне скидання** — при відкритті чату (`mark_read`) лічильник → 0
- **Firestore поле** `unreadCounts: { username: count }` у документі чату

### 📜 Пагінація повідомлень (нове у v2.9.7)
- **Infinite scroll** — при скролі до верху автоматично вантажить ще 50 повідомлень
- **Firebase**: `startAfterDocument` курсор для безшовного підвантаження
- **Windows**: Socket подія `request_history_more` → `load_history_more`
- **Індикатор завантаження** — CircularProgressIndicator в кінці списку

### 📎 Передача файлів (нове у v2.9.7)
- **Підтримувані формати**: PDF, DOCX, DOC, ZIP, TXT (до 20MB)
- **FileBubble** — красива бульбашка з іконкою типу файлу та розміром
- **Signal-style меню** при натисканні: "Відкрити" або "Зберегти"
- **Відкрити** — завантажує у tmpDir та відкриває системним переглядачем
- **Зберегти** — зберігає у папку Download (видно у файловому менеджері)
- **Кирилиця в назвах** — коректне UTF-8 декодування на сервері

### 🔐 Безпека (v2.4.3)
- 🔑 **JWT авторизація** — access token (7д) + refresh token (30д)
- 🔒 **bcrypt паролі** — хешування з rounds=12
- 🛡️ **Rate limiting** — захист від brute-force та DoS
- ⛑️ **Helmet** — HTTP security headers
- ✅ **Joi валідація** — перевірка вхідних даних
- 🔐 **Socket.IO auth** — підключення тільки з валідним JWT

### 👤 Профіль та акаунт (v2.6.0)
- 🪪 **DisplayName vs Username** — displayName (будь-яка мова/кирилиця), username (Latin-only)
- 📱 **Account Tab (Telegram-style)** — аватар з camera badge, статус онлайн, інфо-картка
- 📞 **Телефон та день народження** — збереження в Firestore + видимість
- 🔄 **POST /update_profile** — оновлення всіх полів профілю

### ✓ Статуси повідомлень (v2.6.3–2.6.8)
- **✓ sent** — відправлено (1 кружок, сірий)
- **✓✓ delivered** — доставлено (2 кружки, синя заливка)
- **✓✓ read** — прочитано (2 кружки, сині)
- **Real-time** — оновлення без перезавантаження чату
- **Signal-style CustomPainter** — кружечки з галочками

### Повідомлення
- 💬 **Приватні чати (DM)** — реал-тайм через Firestore + Socket.IO
- 📷 **Надсилання фото** — завантаження у Firebase Storage
- 📎 **Файли** — PDF, DOCX, ZIP з Signal-style меню ✅ NEW
- 🎤 **Голосові повідомлення** — запис AAC + Signal-стиль waveform плеєр
- ↩️ **Reply** — відповідь + swipe-to-reply
- ✏️ **Редагування та видалення** — з позначкою "edited"
- 😊 **Реакції** — emoji toggle
- ⌨️ **Typing indicator** — анімація трьох крапок
- 📜 **Пагінація** — infinite scroll, безкінечне завантаження ✅ NEW

### UI / UX
- 🎨 **Signal Dark UI** — власна дизайн-система `SignalColors` + `AppSizes`
- 🗺 **Плаваюча навігація** — овальна таблетка у Telegram-стилі
- 🔴 **Badge непрочитаних** — на аватарі кожного чату ✅ NEW
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
├── lib/                         └── index.js  (v2.9.7)
│   ├── config/
│   │   └── app_config.dart
│   ├── services/
│   │   ├── socket_service.dart
│   │   └── auth_service.dart
│   ├── utils/
│   │   └── date_utils.dart
│   ├── widgets/
│   │   ├── message_bubble.dart  ← FileBubble + Signal menu ✅ v2.9.7
│   │   ├── swipe_to_reply.dart
│   │   ├── typing_indicator.dart
│   │   ├── date_separator.dart
│   │   ├── reply_preview.dart
│   │   └── reaction_widgets.dart
│   ├── main.dart                ← пагінація + _olderMessages ✅ v2.9.7
│   ├── home_screen.dart         ← unreadCounts Badge ✅ v2.9.7
│   ├── login_screen.dart
│   ├── search_screen.dart
│   ├── settings_screen.dart
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
| POST | `/upload-file` | ✅ | файл → { url, fileName, fileSize } ✅ NEW |
| GET | `/search_users` | ✅ | `?q=&myUsername=` → users[] |
| POST | `/get_or_create_dm` | ✅ | → chat |
| GET | `/get_user_chats` | ✅ | `?username=` → chats[] (Windows) |
| POST | `/update_profile` | ✅ | displayName, phone, birthday, onlineVisible... |
| GET | `/accounts_by_phone` | ❌ | `?phone=` → accounts[] |
| GET | `/ping` | ❌ | health check |

---

## 🗄 Структура Firestore

```
users/{username}
  ├── username, displayName, avatarUrl, passwordHash
  ├── phone, birthday, birthdayVisible, onlineVisible
  └── createdAt

chats/{chatId}
  ├── type: "dm"
  ├── participants: string[]
  ├── participantNames: Map
  ├── lastMessage: { text, sender, timestamp, read }
  └── unreadCounts: { username1: 0, username2: 3 }  ✅ NEW

chats/{chatId}/messages/{messageId}
  ├── text, sender, type, timestamp
  ├── status: "sent"|"delivered"|"read"
  ├── read, edited, editedAt
  ├── replyTo: { id, text, sender }?
  ├── reactions: { "❤️": ["user1"] }?
  ├── audioUrl, audioDuration?
  ├── imageUrl?
  └── fileUrl, fileName, fileSize?  ✅ NEW

fcm_tokens/{token}
  ├── username, updatedAt
```

---

## 🔌 Socket.IO API

### Клієнт → Сервер
| Подія | Дані |
|-------|------|
| `join_chat` | chatId |
| `send_message` | { chatId, text, type, fileUrl?, fileName?, fileSize?, ... } |
| `mark_read` | { chatId, readerUsername } |
| `delete_message` | { messageId, chatId } |
| `edit_message` | { messageId, newText, chatId } |
| `add_reaction` | { messageId, emoji, chatId } |
| `typing` | { chatId } |
| `register_token` | { token } |
| `request_history` | chatId |
| `request_history_more` | { chatId, before: timestamp } ✅ NEW |

### Сервер → Клієнт
| Подія | Дані |
|-------|------|
| `receive_message` | messageData |
| `message_status_update` | { messageId, status } |
| `load_history` | message[] |
| `load_history_more` | message[] ✅ NEW |
| `message_deleted` | messageId |
| `message_edited` | { messageId, newText } |
| `reaction_updated` | { messageId, reactions } |
| `display_typing` | { username, chatId } |

---

## 📋 Changelog

### v2.9.7 — Лютий 2026 — 📎 Файли + 📜 Пагінація + 🔴 Badge
- **Лічильник непрочитаних** — Badge на аватарі чату, Firestore unreadCounts
- **Пагінація повідомлень** — infinite scroll, startAfterDocument, request_history_more
- **Передача файлів** — POST /upload-file, FileBubble, Signal-style меню Відкрити/Зберегти
- **Кирилиця в назвах файлів** — UTF-8 декодування (latin1→utf8)
- **device_info_plus** — правильна перевірка дозволів Android по версії SDK

### v2.6.8 — Лютий 2026 — ✓✓ Статуси (real-time фікс)
- mark_read при receive_message, delivered check всіх сокетів
- _messageStatuses cache для миттєвого UI оновлення

### v2.6.0 — Лютий 2026 — 👤 Профіль + Auth UX
- DisplayName vs Username, AccountTab, Login/Register TabBar

### v2.4.3 — Лютий 2026 — 🔒 Фаза 1: Безпека
- JWT, bcrypt, Socket.IO auth, rate limiting, Helmet, Joi

### v2.3.5 — Лютий 2026
- Push-фільтр, рефакторинг main.dart → widgets/

---

## 🗺 Роадмап

| Фаза | Статус | Задачі |
|------|--------|--------|
| 🔒 **Фаза 1** — Безпека | ✅ **ВИКОНАНО** | JWT, bcrypt, rate-limit, Socket auth |
| 👤 **Профіль** | ✅ **ВИКОНАНО** | AccountTab, displayName, phone, birthday |
| ✓✓ **Статуси** | ✅ **ВИКОНАНО** | sent/delivered/read, real-time, Signal-style |
| 🔴 **Лічильник непрочитаних** | ✅ **ВИКОНАНО** | Badge на аватарі, unreadCounts Firestore |
| 📜 **Пагінація** | ✅ **ВИКОНАНО** | Infinite scroll, startAfterDocument |
| 📎 **Файли** | ✅ **ВИКОНАНО** | PDF/DOCX/ZIP, FileBubble, Відкрити/Зберегти |
| 👥 **Групові чати** | 🔜 **НАСТУПНИЙ** | Групи, адміни, GroupInfoScreen |
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