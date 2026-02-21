# 💬 Messenger Y

> Кросплатформний месенджер у стилі Signal, побудований на Flutter + Node.js

![Version](https://img.shields.io/badge/version-2.3.5-2B5CE6?style=flat-square)
![Flutter](https://img.shields.io/badge/Flutter-3.x-54C5F8?style=flat-square&logo=flutter)
![Node.js](https://img.shields.io/badge/Node.js-20.x-339933?style=flat-square&logo=node.js)
![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%2B%20Storage-FFCA28?style=flat-square&logo=firebase)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows-lightgrey?style=flat-square)

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

## ✨ Функції (v2.3.5)

### Повідомлення
- 💬 **Приватні чати (DM)** — реал-тайм через Firestore + Socket.IO
- 📷 **Надсилання фото** — завантаження у Firebase Storage
- 🎤 **Голосові повідомлення** — запис AAC + Signal-стиль waveform плеєр
- ↩️ **Reply** — відповідь на конкретне повідомлення + swipe-to-reply
- ✏️ **Редагування та видалення** — з позначкою "edited"
- 😊 **Реакції** — emoji toggle (❤️ 👍 😂 та інші)
- ⌨️ **Typing indicator** — анімація трьох крапок

### UI / UX
- 🎨 **Signal Dark UI** — власна дизайн-система `SignalColors` + `AppSizes`
- 🗺 **Плаваюча навігація** — овальна таблетка у Telegram-стилі
- 📅 **Розділювачі дат** + Scroll Date Overlay при скролі
- 📋 **Контекстне меню** — blur overlay з реакціями та діями

### Технічне
- 🔔 **FCM Push Notifications** — надсилаються тільки учасникам чату
- 🪟 **Windows підтримка** — HTTP fallback + Socket.IO (без Firebase)
- 🚀 **Shorebird OTA** — оновлення без перевидання у Store
- 🔍 **Пошук користувачів** — за нікнеймом

---

## 🏗 Архітектура

```
client/                          server/
├── lib/                         └── index.js
│   ├── config/
│   │   └── app_config.dart      ← serverUrl з .env
│   ├── services/
│   │   └── socket_service.dart  ← Socket.IO singleton
│   ├── utils/
│   │   └── date_utils.dart      ← ChatDateUtils
│   ├── widgets/
│   │   ├── message_bubble.dart
│   │   ├── swipe_to_reply.dart
│   │   ├── typing_indicator.dart
│   │   ├── date_separator.dart
│   │   ├── reply_preview.dart
│   │   └── reaction_widgets.dart
│   ├── main.dart                ← MyApp + ChatScreen
│   ├── home_screen.dart         ← HomeScreen + OvalNavBar
│   ├── login_screen.dart
│   ├── search_screen.dart
│   ├── settings_screen.dart     ← OTA оновлення
│   ├── signal_context_menu.dart
│   ├── audio_player_widget.dart ← Waveform плеєр
│   ├── voice_recorder.dart
│   └── theme.dart               ← SignalColors + AppSizes
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

# 2. Додай змінні оточення
cp .env.example .env
# Відредагуй .env: FIREBASE_PROJECT_ID, BUCKET_NAME, PORT

# 3. Поклади serviceAccountKey.json у корінь server/

# 4. Запусти
node index.js
# або з nodemon:
npx nodemon index.js
```

---

## ⚙️ Змінні оточення

### client/.env
```env
SERVER_URL=https://your-server.onrender.com
```

### server/.env
```env
PORT=3000
FIREBASE_PROJECT_ID=your-project-id
BUCKET_NAME=your-project.firebasestorage.app
JWT_SECRET=change_me_in_production
```

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
audioplayers: ^6.5.1
record: ^6.2.0
image_picker: ^1.2.1
shorebird_code_push: ^2.0.5
shared_preferences: ^2.5.4
vibration: ^3.1.6
permission_handler: ^12.0.1
path_provider: ^2.1.1
http: ^1.6.0
```

### Node.js (package.json)
```json
{
  "dependencies": {
    "express": "^5.0.0",
    "socket.io": "^4.8.0",
    "firebase-admin": "^13.0.0",
    "@google-cloud/storage": "^7.0.0",
    "multer": "^1.4.5",
    "cors": "^2.8.5"
  }
}
```

---

## 🗄 Структура Firestore

```
users/{username}
  ├── username: string
  ├── avatarUrl: string?
  └── createdAt: timestamp

chats/{chatId}
  ├── type: "dm" | "group"
  ├── participants: string[]
  └── lastMessage: { text, sender, timestamp, read }

chats/{chatId}/messages/{messageId}
  ├── text: string
  ├── sender: string
  ├── type: "text" | "image" | "voice"
  ├── timestamp: timestamp
  ├── read: boolean
  ├── edited: boolean?
  ├── replyTo: { id, text, sender }?
  ├── reactions: { "❤️": ["user1"], ... }?
  ├── audioUrl: string?
  └── audioDuration: int?

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
| `send_message` | { chatId, text, sender, type, replyTo?, audioUrl? } |
| `delete_message` | { messageId, chatId } |
| `edit_message` | { messageId, newText, username, chatId } |
| `add_reaction` | { messageId, emoji, username, chatId } |
| `typing` | { username, chatId } |
| `mark_read` | { chatId } |
| `register_token` | { token, username } |
| `request_history` | chatId |

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

## 🌐 REST API

| Метод | Ендпоінт | Опис |
|-------|----------|------|
| POST | `/auth` | Вхід / реєстрація |
| POST | `/upload` | Завантажити фото |
| POST | `/upload-audio` | Завантажити аудіо |
| GET | `/search_users?q=&myUsername=` | Пошук юзерів |
| POST | `/get_or_create_dm` | Отримати або створити DM чат |
| GET | `/get_user_chats?username=` | Список чатів (Windows) |
| GET | `/ping` | Health check |

---

## 📋 Changelog

### v2.3.5 — Лютий 2026 (поточна)
**🔴 Виправлені критичні баги:**
- Push-сповіщення тепер надсилаються тільки учасникам чату (раніше — всім)
- Автоматичне видалення невалідних FCM токенів
- `maxHttpBufferSize` зменшено з 60MB до 10MB (захист від DoS)
- Додано Graceful shutdown (`SIGTERM`/`SIGINT`) на сервері
- Видалено дублікат `LoginScreen` з `main.dart`

**🟠 Рефакторинг:**
- `main.dart` розбито на `widgets/` (MessageBubble, SwipeToReply, TypingIndicator, DateSeparator, ReplyPreview, ReactionWidgets)
- Створено `SocketService` singleton — всі `socket.emit` замінено на типізовані методи
- Створено `ChatDateUtils` у `utils/date_utils.dart` — видалено дублювання `_formatTime()`
- Створено `AppConfig` — `serverUrl` тепер зчитується з `.env` файлу
- `firebaseAvailable` перенесено з глобальної змінної до `AppConfig`

### v2.3.0 — Січень 2026
- Голосові повідомлення + Signal-стиль waveform плеєр
- Waveform рендер через `CustomPainter`
- VoiceRecorder widget з анімацією

### v2.2.0
- Signal Dark UI система (SignalColors + AppSizes)
- Плаваюча овальна навігація
- Контекстне меню SignalContextMenu

### v2.1.0
- Typing indicator з анімацією
- Розділювачі дат + Scroll Date Overlay
- Swipe-to-reply

### v2.0.0
- Реакції на повідомлення
- Редагування та видалення
- Reply функціональність
- Windows підтримка (HTTP fallback)

### v1.0.0
- Початковий реліз
- DM чати, авторизація, фото, push, Shorebird OTA

---

## 🗺 Роадмап

| Фаза | Терміни | Задачі |
|------|---------|--------|
| 🔒 **Фаза 1** — Безпека | Березень–Квітень 2026 | JWT, bcrypt паролі, rate-limit, Socket.IO auth |
| 💬 **Фаза 2** — Чат 2.0 | Травень–Червень 2026 | Статуси ✓✓✓, онлайн, пагінація, файли, групи, WebRTC |
| 👥 **Фаза 3** — Соціальні | Липень–Серпень 2026 | Профілі, Сторіз, контакти |
| 🚀 **Фаза 4** — DevOps | Вересень–Жовтень 2026 | Redis, CI/CD, тести, Sentry |
| 🔐 **Фаза 5** — E2EE+ | Листопад 2026+ | Шифрування, монетизація, Web/macOS |

Детальний план: [`Messenger_Y_Plan_v5.docx`](./docs/Messenger_Y_Plan_v5.docx)

---

## 🤝 Контриб'ютинг

1. Fork репо
2. Створи гілку: `git checkout -b feature/назва-функції`
3. Зроби зміни та `flutter analyze` — 0 errors
4. Відкрий Pull Request

---

## 📄 Ліцензія

MIT License — деталі у файлі [LICENSE](LICENSE)

---

<p align="center">
  Зроблено з ❤️ на Flutter + Node.js
</p>