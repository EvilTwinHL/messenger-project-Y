const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const Joi = require('joi');

// --- НАЛАШТУВАННЯ ---
const BUCKET_NAME = "project-y-8df27.firebasestorage.app";
const JWT_SECRET = process.env.JWT_SECRET || "change_me_in_production_please";
const JWT_EXPIRES_IN = "7d";
const JWT_REFRESH_EXPIRES_IN = "30d";
// --------------------

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: BUCKET_NAME
});

const db = admin.firestore();
const bucket = admin.storage().bucket();

const app = express();

// ==========================================
// 🛡️ БЕЗПЕКА — Helmet + Morgan + CORS
// ==========================================
app.use(helmet());
app.use(morgan('combined'));
app.use(cors());
app.set('trust proxy', 1);
app.use(express.json());

// ==========================================
// ⏱️ RATE LIMITING
// ==========================================
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 хвилин
  max: 10,
  message: { error: 'Забагато спроб входу. Спробуй через 15 хвилин.' },
  standardHeaders: true,
  legacyHeaders: false,
});

const uploadLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 хвилина
  max: 30,
  message: { error: 'Забагато завантажень. Зачекай хвилину.' },
});

const searchLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 60,
  message: { error: 'Забагато запитів пошуку.' },
});

// ==========================================
// 🔐 JOI СХЕМИ ВАЛІДАЦІЇ
// ==========================================
const authSchema = Joi.object({
  // ✅ Логін — тільки латиниця, цифри, крапка, підкреслення, дефіс
  // Кирилиця НЕ дозволена — логін використовується як унікальний ідентифікатор
  username: Joi.string().min(3).max(20).pattern(/^[a-zA-Z0-9._-]+$/).required()
    .messages({
      'string.pattern.base': "Логін може містити тільки латинські літери (a-z), цифри та символи . _ -",
      'string.min': "Логін мінімум 3 символи",
      'string.max': "Логін максимум 20 символів",
      'any.required': "Логін обов'язковий",
    }),
  password: Joi.string().min(8).required()
    .messages({
      'string.min': "Пароль мінімум 8 символів",
      'any.required': "Пароль обов'язковий",
    }),
  avatarUrl: Joi.string().uri().optional().allow(null, ''),
});

const refreshSchema = Joi.object({
  refreshToken: Joi.string().required(),
});

// ==========================================
// 🔑 MIDDLEWARE — verifyJWT
// ==========================================
const verifyJWT = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // "Bearer <token>"

  if (!token) {
    return res.status(401).json({ error: 'Токен відсутній' });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded; // { username, iat, exp }
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Токен протермінований', expired: true });
    }
    return res.status(403).json({ error: 'Недійсний токен' });
  }
};

// ==========================================
// 🔐 1. АВТОРИЗАЦІЯ — з паролем + JWT
// ==========================================
app.post('/auth', authLimiter, async (req, res) => {
  // Joi валідація
  const { error, value } = authSchema.validate(req.body);
  if (error) {
    return res.status(400).json({ error: error.details[0].message });
  }

  const { username, password, avatarUrl } = value;

  try {
    const usersRef = db.collection('users');
    const snapshot = await usersRef.where('username', '==', username).get();

    let userData;
    let docId;

    if (snapshot.empty) {
      // 🆕 РЕЄСТРАЦІЯ — новий користувач
      const passwordHash = await bcrypt.hash(password, 12);
      const newUser = {
        username,
        avatarUrl: avatarUrl || null,
        passwordHash,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      const docRef = await usersRef.add(newUser);
      docId = docRef.id;
      userData = newUser;

      // Генеруємо токени
      const token = jwt.sign({ username }, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
      const refreshToken = jwt.sign({ username, type: 'refresh' }, JWT_SECRET, { expiresIn: JWT_REFRESH_EXPIRES_IN });

      return res.json({
        status: 'created',
        token,
        refreshToken,
        user: { username, avatarUrl: userData.avatarUrl }
      });

    } else {
      // 🔓 ВХІД — перевіряємо пароль
      docId = snapshot.docs[0].id;
      userData = snapshot.docs[0].data();

      // Якщо у старого акаунта немає passwordHash — встановлюємо пароль
      if (!userData.passwordHash) {
        const passwordHash = await bcrypt.hash(password, 12);
        await usersRef.doc(docId).update({ passwordHash });
        userData.passwordHash = passwordHash;
      }

      const isPasswordValid = await bcrypt.compare(password, userData.passwordHash);
      if (!isPasswordValid) {
        return res.status(401).json({ error: 'Невірний пароль' });
      }

      // Оновлюємо аватар якщо є
      if (avatarUrl && avatarUrl !== userData.avatarUrl) {
        await usersRef.doc(docId).update({ avatarUrl });
        userData.avatarUrl = avatarUrl;
      }

      const token = jwt.sign({ username }, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
      const refreshToken = jwt.sign({ username, type: 'refresh' }, JWT_SECRET, { expiresIn: JWT_REFRESH_EXPIRES_IN });

      return res.json({
        status: 'found',
        token,
        refreshToken,
        user: { username, avatarUrl: userData.avatarUrl }
      });
    }

  } catch (err) {
    console.error("Auth Error:", err);
    res.status(500).json({ error: "Помилка сервера при вході" });
  }
});

// ==========================================
// 🔄 REFRESH TOKEN
// ==========================================
app.post('/refresh', async (req, res) => {
  const { error, value } = refreshSchema.validate(req.body);
  if (error) {
    return res.status(400).json({ error: 'refreshToken обов\'язковий' });
  }

  try {
    const decoded = jwt.verify(value.refreshToken, JWT_SECRET);

    if (decoded.type !== 'refresh') {
      return res.status(403).json({ error: 'Невірний тип токена' });
    }

    const newToken = jwt.sign(
      { username: decoded.username },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN }
    );

    res.json({ token: newToken });
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Refresh токен протермінований. Увійдіть знову.', expired: true });
    }
    res.status(403).json({ error: 'Недійсний refresh токен' });
  }
});

// ==========================================
// 📂 2. ЗАВАНТАЖЕННЯ ФОТО (захищено)
// ==========================================
const multer = require('multer');
const fs = require('fs');
const upload = multer({ dest: 'uploads/' });

app.post('/upload', verifyJWT, uploadLimiter, upload.single('image'), async (req, res) => {
  if (!req.file) return res.status(400).send('No file');

  try {
    const localFilePath = req.file.path;
    const safeName = req.file.originalname.replace(/[^a-zA-Z0-9.]/g, "_");
    const remoteFileName = `images/${Date.now()}_${safeName}`;

    await bucket.upload(localFilePath, {
      destination: remoteFileName,
      metadata: { contentType: req.file.mimetype }
    });

    const file = bucket.file(remoteFileName);
    const [url] = await file.getSignedUrl({ action: 'read', expires: '03-01-2500' });

    fs.unlinkSync(localFilePath);
    res.json({ url });

  } catch (err) {
    console.error("Помилка завантаження:", err);
    res.status(500).send("Upload failed");
  }
});

// ==========================================
// 🎤 3. ЗАВАНТАЖЕННЯ АУДІО (захищено)
// ==========================================
app.post('/upload-audio', verifyJWT, uploadLimiter, upload.single('audio'), async (req, res) => {
  if (!req.file) return res.status(400).send('No audio file');

  try {
    const localFilePath = req.file.path;
    const safeName = req.file.originalname.replace(/[^a-zA-Z0-9.]/g, "_");
    const remoteFileName = `audio/${Date.now()}_${safeName}`;

    await bucket.upload(localFilePath, {
      destination: remoteFileName,
      metadata: { contentType: req.file.mimetype || 'audio/aac' }
    });

    const file = bucket.file(remoteFileName);
    const [url] = await file.getSignedUrl({ action: 'read', expires: '03-01-2500' });

    fs.unlinkSync(localFilePath);
    res.json({ url });

  } catch (err) {
    console.error("Помилка завантаження аудіо:", err);
    res.status(500).send("Audio upload failed");
  }
});

// ==========================================
// 🔍 4. ПОШУК КОРИСТУВАЧІВ (захищено)
// ==========================================
app.get('/search_users', verifyJWT, searchLimiter, async (req, res) => {
  const query = req.query.q;
  const myUsername = req.query.myUsername;

  if (!query) return res.json([]);

  try {
    const snapshot = await db.collection('users')
      .where('username', '>=', query)
      .where('username', '<=', query + '\uf8ff')
      .limit(10)
      .get();

    const users = snapshot.docs
      .map(doc => doc.data())
      .filter(u => u.username !== myUsername)
      .map(u => ({ username: u.username, avatarUrl: u.avatarUrl })); // НЕ повертаємо passwordHash!

    res.json(users);
  } catch (err) {
    console.error("Search error:", err);
    res.status(500).json({ error: "Search failed" });
  }
});

// ==========================================
// 💬 5. СТВОРЕННЯ/ОТРИМАННЯ DM (захищено)
// ==========================================
app.post('/get_or_create_dm', verifyJWT, async (req, res) => {
  const { myUsername, otherUsername } = req.body;
  if (!myUsername || !otherUsername) return res.status(400).send("No usernames");

  // Перевіряємо що токен збігається з myUsername
  if (req.user.username !== myUsername) {
    return res.status(403).json({ error: 'Доступ заборонено' });
  }

  try {
    const chatsRef = db.collection('chats');
    const snapshot = await chatsRef
      .where('participants', 'array-contains', myUsername)
      .get();

    let existingChat = null;
    snapshot.forEach(doc => {
      const data = doc.data();
      if (data.type === 'dm' && data.participants.includes(otherUsername)) {
        existingChat = { id: doc.id, ...data };
      }
    });

    if (existingChat) return res.json(existingChat);

    const newChat = {
      type: 'dm',
      participants: [myUsername, otherUsername],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastMessage: null
    };
    const docRef = await chatsRef.add(newChat);
    res.json({ id: docRef.id, ...newChat });

  } catch (err) {
    console.error("Create DM error:", err);
    res.status(500).json({ error: "Failed to get chat" });
  }
});

// ==========================================
// 🖥️ 6. СПИСОК ЧАТІВ для Windows (захищено)
// ==========================================
app.get('/get_user_chats', verifyJWT, async (req, res) => {
  const { username } = req.query;
  if (!username) return res.status(400).json({ error: "No username" });

  if (req.user.username !== username) {
    return res.status(403).json({ error: 'Доступ заборонено' });
  }

  try {
    const snapshot = await db.collection('chats')
      .where('participants', 'array-contains', username)
      .get();

    const chats = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate?.()?.toISOString() || null,
    }));

    chats.sort((a, b) => {
      const aTs = a.lastMessage?.timestamp;
      const bTs = b.lastMessage?.timestamp;
      if (!aTs && !bTs) return 0;
      if (!aTs) return 1;
      if (!bTs) return -1;
      return new Date(bTs) - new Date(aTs);
    });

    res.json(chats);
  } catch (err) {
    console.error("Get chats error:", err);
    res.status(500).json({ error: "Failed to get chats" });
  }
});

// ==========================================
// 🚀 SOCKET.IO СЕРВЕР
// ==========================================
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: "*" },
  maxHttpBufferSize: 1e7,
  pingTimeout: 60000,
  pingInterval: 25000,
});

// 🔐 Socket.IO JWT middleware
io.use((socket, next) => {
  const token = socket.handshake.auth?.token;

  if (!token) {
    return next(new Error('Токен відсутній'));
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    socket.username = decoded.username; // зберігаємо username у сокеті
    next();
  } catch (err) {
    next(new Error('Недійсний токен'));
  }
});

const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send('Messenger Y Server v2.4.1 🔐');
});

app.get('/ping', (req, res) => {
  console.log('pinged');
  res.send('pong');
});

io.on('connection', async (socket) => {
  console.log(`[CONN] ${socket.username} підключився: ${socket.id}`);

  socket.on('debug_log', (msg) => {
    console.log(`📱 CLIENT LOG [${socket.username}]:`, msg);
  });

  socket.on('join_chat', (chatId) => {
    socket.join(chatId);
    console.log(`${socket.username} зайшов у кімнату: ${chatId}`);
  });

  socket.on('leave_chat', (chatId) => {
    socket.leave(chatId);
    console.log(`${socket.username} вийшов з кімнати: ${chatId}`);
  });

  socket.on('register_token', async (data) => {
    let token = "";
    let username = socket.username; // беремо з JWT, не від клієнта

    if (typeof data === 'string') {
      token = data;
    } else if (typeof data === 'object' && data.token) {
      token = data.token;
    }

    if (token) {
      try {
        await db.collection('fcm_tokens').doc(token).set({
          username,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      } catch (e) {
        console.error("❌ Помилка запису токена:", e);
      }
    }
  });

  socket.on('request_history', async (chatId) => {
    if (!chatId) return;
    try {
      const snapshot = await db.collection('chats').doc(chatId)
        .collection('messages')
        .orderBy('timestamp', 'desc')
        .limit(50)
        .get();

      const history = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })).reverse();
      socket.emit('load_history', history);
    } catch (err) {
      console.error("Помилка історії:", err);
    }
  });

  socket.on('send_message', async (data) => {
    const { chatId, text, type } = data;
    const sender = socket.username; // з JWT, не від клієнта!

    if (!chatId) return;

    const messageData = {
      chatId,
      text: text || '',
      sender,
      senderAvatar: data.senderAvatar || null,
      type: type || 'text',
      imageUrl: data.imageUrl || null,
      replyTo: data.replyTo || null,
      audioUrl: data.audioUrl || null,
      audioDuration: data.audioDuration || null,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      read: false
    };

    const docRef = await db.collection('chats').doc(chatId)
      .collection('messages').add(messageData);

    await db.collection('chats').doc(chatId).update({
      lastMessage: {
        text: type === 'image' ? '📷 Фото' : (type === 'voice' ? '🎤 Голосове' : text),
        sender,
        timestamp: new Date().toISOString(),
        read: false
      }
    });

    const savedMessage = { id: docRef.id, ...messageData, timestamp: new Date().toISOString() };
    io.to(chatId).emit('receive_message', savedMessage);

    // FCM Push
    try {
      const chatDoc = await db.collection("chats").doc(chatId).get();
      const participants = chatDoc.data()?.participants || [];
      const recipients = participants.filter(u => u !== sender);

      if (recipients.length === 0) return;

      const tokensSnap = await db.collection("fcm_tokens")
        .where("username", "in", recipients).get();
      const tokens = tokensSnap.docs.map(doc => doc.id);

      if (tokens.length > 0) {
        const payload = {
          notification: {
            title: `Нове від ${sender}`,
            body: type === 'image' ? '📷 Фото' : type === 'voice' ? '🎤 Голосове' : text,
          },
          data: { chatId, sender },
          tokens,
        };
        const result = await admin.messaging().sendEachForMulticast(payload);
        result.responses.forEach((r, i) => {
          if (!r.success && r.error?.code === "messaging/registration-token-not-registered") {
            db.collection("fcm_tokens").doc(tokens[i]).delete();
          }
        });
      }
    } catch (err) {
      console.error("Помилка пушів:", err);
    }
  });

  socket.on('typing', (data) => {
    if (data.chatId) {
      socket.to(data.chatId).emit('display_typing', {
        username: socket.username, // з JWT
        chatId: data.chatId
      });
    }
  });

  socket.on('delete_message', async ({ messageId, chatId }) => {
    if (!chatId) return;
    try {
      await db.collection('chats').doc(chatId)
        .collection('messages').doc(messageId).delete();
      io.to(chatId).emit('message_deleted', messageId);
    } catch (err) {
      console.error("Помилка видалення:", err);
    }
  });

  socket.on('mark_read', async (data) => {
    if (data.chatId) {
      io.to(data.chatId).emit('message_read_update', data);
    }
  });

  socket.on('add_reaction', async ({ messageId, emoji, chatId }) => {
    if (!chatId) return;
    const username = socket.username; // з JWT

    try {
      const messageRef = db.collection('chats').doc(chatId)
        .collection('messages').doc(messageId);
      const messageDoc = await messageRef.get();
      if (!messageDoc.exists) return;

      const currentReactions = messageDoc.data().reactions || {};
      if (!currentReactions[emoji]) currentReactions[emoji] = [];

      const idx = currentReactions[emoji].indexOf(username);
      if (idx === -1) {
        currentReactions[emoji].push(username);
      } else {
        currentReactions[emoji].splice(idx, 1);
        if (currentReactions[emoji].length === 0) delete currentReactions[emoji];
      }

      await messageRef.update({ reactions: currentReactions });
      io.to(chatId).emit('reaction_updated', { messageId, reactions: currentReactions });

    } catch (err) {
      console.error("Помилка реакції:", err);
    }
  });

  socket.on('edit_message', async ({ messageId, newText, chatId }) => {
    if (!chatId) return;
    const username = socket.username; // з JWT

    try {
      const messageRef = db.collection('chats').doc(chatId)
        .collection('messages').doc(messageId);
      const messageDoc = await messageRef.get();

      if (!messageDoc.exists) return;
      if (messageDoc.data().sender !== username) return; // тільки свої

      await messageRef.update({
        text: newText,
        edited: true,
        editedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      io.to(chatId).emit('message_edited', { messageId, newText, edited: true });
    } catch (err) {
      console.error("Помилка редагування:", err);
    }
  });

  socket.on('disconnect', () => {
    console.log(`[DISC] ${socket.username} відключився: ${socket.id}`);
  });
});

// ==========================================
// ✅ Graceful Shutdown
// ==========================================
server.listen(PORT, () => {
  console.log(`🔐 Messenger Y Server v2.4.1 running on port ${PORT}`);
});

const shutdown = () => {
  console.log('Shutting down gracefully...');
  io.close(() => {
    server.close(() => {
      console.log('Server closed.');
      process.exit(0);
    });
  });
  setTimeout(() => process.exit(1), 10000);
};

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);