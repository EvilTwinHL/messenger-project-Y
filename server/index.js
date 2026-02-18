const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
var admin = require("firebase-admin");
var serviceAccount = require("./serviceAccountKey.json");

// --- НАЛАШТУВАННЯ ---
const BUCKET_NAME = "project-y-8df27.firebasestorage.app"; 
// --------------------

// Ініціалізація з Bucket
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: BUCKET_NAME 
});

const db = admin.firestore();
const bucket = admin.storage().bucket(); // Підключаємось до сховища

const app = express();
app.use(cors());
app.use(express.json()); // 🔥 ВАЖЛИВО: Додано для обробки JSON при авторизації

// Налаштування Multer (тимчасове зберігання файлу перед відправкою в хмару)
const multer = require('multer');
const fs = require('fs');
const upload = multer({ dest: 'uploads/' }); // Тимчасова папка

// ==========================================
// 🔐 1. АВТОРИЗАЦІЯ (Без змін)
// ==========================================
app.post('/auth', async (req, res) => {
    const { username, avatarUrl } = req.body;

    if (!username || username.trim().length === 0) {
        return res.status(400).json({ error: "Ім'я не може бути пустим" });
    }

    try {
        const usersRef = db.collection('users');
        const snapshot = await usersRef.where('username', '==', username).get();

        if (snapshot.empty) {
            // Створюємо нового користувача
            const newUser = {
                username: username,
                avatarUrl: avatarUrl || null,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            await usersRef.add(newUser);
            return res.json({ status: 'created', user: newUser });
        } else {
            // Існуючий користувач
            const docId = snapshot.docs[0].id;
            if (avatarUrl) {
                await usersRef.doc(docId).update({ avatarUrl: avatarUrl });
            }
            
            const userData = snapshot.docs[0].data();
            userData.avatarUrl = avatarUrl || userData.avatarUrl;
            
            return res.json({ status: 'found', user: userData });
        }
    } catch (error) {
        console.error("Auth Error:", error);
        res.status(500).json({ error: "Помилка сервера при вході" });
    }
});

// ==========================================
// 📂 2. ЗАВАНТАЖЕННЯ ФОТО (Без змін)
// ==========================================
app.post('/upload', upload.single('image'), async (req, res) => {
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
        const [url] = await file.getSignedUrl({
            action: 'read',
            expires: '03-01-2500' 
        });

        fs.unlinkSync(localFilePath);
        res.json({ url: url });

    } catch (error) {
        console.error("Помилка завантаження:", error);
        res.status(500).send("Upload failed");
    }
});

// ==========================================
// 🎤 3. ЗАВАНТАЖЕННЯ АУДІО (Без змін)
// ==========================================
app.post('/upload-audio', upload.single('audio'), async (req, res) => {
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
        const [url] = await file.getSignedUrl({
            action: 'read',
            expires: '03-01-2500'
        });

        fs.unlinkSync(localFilePath);
        res.json({ url: url });

    } catch (error) {
        console.error("Помилка завантаження аудіо:", error);
        res.status(500).send("Audio upload failed");
    }
});

// ==========================================
// 🔥 НОВЕ: API ДЛЯ ПОШУКУ ТА ЧАТІВ
// ==========================================

// 🔍 4. Пошук користувачів
app.get('/search_users', async (req, res) => {
    const query = req.query.q;
    const myUsername = req.query.myUsername; 

    if (!query) return res.json([]);

    try {
        // Пошук по початку рядка (еквівалент SQL LIKE 'query%')
        const usersRef = db.collection('users');
        const snapshot = await usersRef
            .where('username', '>=', query)
            .where('username', '<=', query + '\uf8ff')
            .limit(10)
            .get();

        const users = snapshot.docs
            .map(doc => doc.data())
            .filter(user => user.username !== myUsername); // Фільтруємо себе

        res.json(users);
    } catch (e) {
        console.error("Search error:", e);
        res.status(500).json({ error: "Search failed" });
    }
});

// 💬 5. Створення або отримання DM (Приватного чату)
app.post('/get_or_create_dm', async (req, res) => {
    const { myUsername, otherUsername } = req.body;
    if (!myUsername || !otherUsername) return res.status(400).send("No usernames");

    try {
        const chatsRef = db.collection('chats');

        // Шукаємо чати, де є ТИ
        const snapshot = await chatsRef
            .where('participants', 'array-contains', myUsername)
            .get();

        let existingChat = null;

        // Фільтруємо результати, щоб знайти чат саме з ІНШИМ користувачем
        snapshot.forEach(doc => {
            const data = doc.data();
            if (data.type === 'dm' && data.participants.includes(otherUsername)) {
                existingChat = { id: doc.id, ...data };
            }
        });

        if (existingChat) {
            return res.json(existingChat);
        }

        // Створюємо новий чат, якщо не знайдено
        const newChat = {
            type: 'dm',
            participants: [myUsername, otherUsername],
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            lastMessage: null
        };

        const docRef = await chatsRef.add(newChat);
        res.json({ id: docRef.id, ...newChat });

    } catch (e) {
        console.error("Create DM error:", e);
        res.status(500).json({ error: "Failed to get chat" });
    }
});

// ==========================================
// 🚀 SOCKET.IO СЕРВЕР
// ==========================================

const server = http.createServer(app);
const io = new Server(server, { 
    cors: { origin: "*" },
    maxHttpBufferSize: 6e7 // 10 MB
});

const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
    res.send('Server Running (Rooms & DM Enabled) 🚀');
});

app.get('/ping', (req, res) => {
    console.log('pinged');
    res.send('pong');
});

io.on('connection', async (socket) => {
    console.log(`[CONN] Користувач підключився: ${socket.id}`);

    // 🔥 Логи з телефону
    socket.on('debug_log', (msg) => {
        console.log(`📱 CLIENT LOG [${socket.id}]:`, msg);
    });

    // --- 1. ВХІД У КІМНАТУ (Join Room) ---
    // Клієнт повинен надіслати цей івент при вході в конкретний чат
    socket.on('join_chat', (chatId) => {
        socket.join(chatId);
        console.log(`Socket ${socket.id} зайшов у кімнату: ${chatId}`);
    });

    // --- 2. ВИХІД З КІМНАТИ (Leave Room) ---
    socket.on('leave_chat', (chatId) => {
        socket.leave(chatId);
        console.log(`Socket ${socket.id} вийшов з кімнати: ${chatId}`);
    });

    // --- 3. РЕЄСТРАЦІЯ ТОКЕНА (Push Notifications) ---
    socket.on('register_token', async (data) => {
        let token = "";
        let username = null;

        if (typeof data === 'string') {
            token = data;
        } else if (typeof data === 'object' && data.token) {
            token = data.token;
            username = data.username;
        }

        if(token) {
            try {
                await db.collection('fcm_tokens').doc(token).set({
                    username: username,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                });
            } catch (e) {
                console.error("❌ Помилка запису токена:", e);
            }
        }
    });

    // --- 4. ЗАВАНТАЖЕННЯ ІСТОРІЇ (ОНОВЛЕНО: Тільки для конкретного чату) ---
    socket.on('request_history', async (chatId) => {
        if (!chatId) return;

        try {
            // 🔥 ВИПРАВЛЕНО: Читаємо з підколекції 'messages' конкретного чату
            const messagesRef = db.collection('chats').doc(chatId).collection('messages');
            
            const snapshot = await messagesRef
                .orderBy('timestamp', 'desc')
                .limit(50)
                .get();
            
            let history = snapshot.docs.map(doc => ({
                id: doc.id,
                ...doc.data()
            }));

            history = history.reverse();
            // Відправляємо історію ТІЛЬКИ тому, хто запитав
            socket.emit('load_history', history);
        } catch (error) {
            console.error("Помилка історії:", error);
        }
    });

    // --- 5. ВІДПРАВКА ПОВІДОМЛЕННЯ (В КІМНАТУ) ---
    socket.on('send_message', async (data) => {
        const { chatId, text, sender, type } = data;

        if (!chatId) {
            console.error("❌ Спроба відправити повідомлення без chatId");
            return;
        }

        const messageData = {
            chatId: chatId, 
            text: text || '',
            sender: sender,
            senderAvatar: data.senderAvatar || null,
            type: type || 'text',
            imageUrl: data.imageUrl || null,
            replyTo: data.replyTo || null,
            audioUrl: data.audioUrl || null,
            audioDuration: data.audioDuration || null,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            read: false
        };

        // А) 🔥 ВИПРАВЛЕНО: Зберігаємо в підколекцію 'messages' цього чату
        const docRef = await db.collection('chats').doc(chatId).collection('messages').add(messageData);
        
        // Б) Оновлюємо `lastMessage` в самому чаті (для списку чатів)
        await db.collection('chats').doc(chatId).update({
            lastMessage: {
                text: type === 'image' ? '📷 Фото' : (type === 'voice' ? '🎤 Голосове' : text),
                sender: sender,
                timestamp: new Date().toISOString(),
                read: false
            }
        });

        // В) Формуємо об'єкт для клієнта
        const savedMessage = {
            id: docRef.id,
            ...messageData,
            timestamp: new Date().toISOString()
        };
        
        // Г) Відправляємо ТІЛЬКИ в цю кімнату (chatId)
        io.to(chatId).emit('receive_message', savedMessage); 

        // Д) ВІДПРАВЛЯЄМО ПУШ-СПОВІЩЕННЯ
        try {
            const tokensSnapshot = await db.collection('fcm_tokens').get();
            const tokens = tokensSnapshot.docs
                .filter(doc => doc.data().username !== sender)
                .map(doc => doc.id);

            if (tokens.length > 0) {
                const payload = {
                    notification: {
                        title: `Нове від ${sender}`,
                        body: type === 'image' ? '📷 Фото' : (type === 'voice' ? '🎤 Голосове' : text),
                    },
                    tokens: tokens,
                };
                await admin.messaging().sendEachForMulticast(payload);
            }
        } catch (error) {
            console.error("Помилка розсилки пушів:", error);
        }
    });

    // --- 6. ІНДИКАТОР НАБОРУ (В КІМНАТУ) ---
    socket.on('typing', (data) => {
        if (data.chatId) {
            socket.to(data.chatId).emit('display_typing', data);
        }
    });

    // --- 7. ВИДАЛЕННЯ ПОВІДОМЛЕННЯ (В КІМНАТУ) ---
    socket.on('delete_message', async ({ messageId, chatId }) => {
        if (!chatId) return; // chatId обов'язковий
        try {
            // 🔥 ВИПРАВЛЕНО: Видаляємо з підколекції
            await db.collection('chats').doc(chatId).collection('messages').doc(messageId).delete();
            
            io.to(chatId).emit('message_deleted', messageId);
        } catch (e) {
            console.error("Помилка видалення:", e);
        }
    });

    // --- 8. СТАТУС ПРОЧИТАНО (В КІМНАТУ) ---
    socket.on('mark_read', async (data) => {
        if (data.chatId) {
            // Можна додати оновлення в БД, але поки тільки сповіщення
            io.to(data.chatId).emit('message_read_update', data);
        }
    });

    // --- 9. РЕАКЦІЇ (В КІМНАТУ) ---
    socket.on('add_reaction', async ({ messageId, emoji, username, chatId }) => {
        if (!chatId) return;
        try {
             // 🔥 ВИПРАВЛЕНО: Шукаємо повідомлення в підколекції
             const messageRef = db.collection('chats').doc(chatId).collection('messages').doc(messageId);
             const messageDoc = await messageRef.get();
             if (!messageDoc.exists) return;
            
             const messageData = messageDoc.data();
             const currentReactions = messageData.reactions || {};
            
             if (!currentReactions[emoji]) currentReactions[emoji] = [];
            
             const userIndex = currentReactions[emoji].indexOf(username);
             if (userIndex === -1) {
                currentReactions[emoji].push(username);
             } else {
                currentReactions[emoji].splice(userIndex, 1);
                if (currentReactions[emoji].length === 0) delete currentReactions[emoji];
             }
            
             await messageRef.update({ reactions: currentReactions });
             
             const updateData = { messageId, reactions: currentReactions };
             io.to(chatId).emit('reaction_updated', updateData);
             
        } catch (error) {
            console.error("Помилка реакції:", error);
        }
    });

    // --- 10. РЕДАГУВАННЯ (В КІМНАТУ) ---
    socket.on('edit_message', async ({ messageId, newText, username, chatId }) => {
        if (!chatId) return;
        try {
            // 🔥 ВИПРАВЛЕНО: Шукаємо повідомлення в підколекції
            const messageRef = db.collection('chats').doc(chatId).collection('messages').doc(messageId);
            const messageDoc = await messageRef.get();
            
            if (!messageDoc.exists) return;
            if (messageDoc.data().sender !== username) return;
            
            await messageRef.update({
                text: newText,
                edited: true,
                editedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            
            const updateData = { messageId, newText, edited: true };
            io.to(chatId).emit('message_edited', updateData);
        } catch (error) {
            console.error("Помилка редагування:", error);
        }
    });

    socket.on('disconnect', () => {
        console.log(`[DISC] Відключено: ${socket.id}`);
    });
});

server.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});

// NEW 18.02.2026 add 'rooms' and 'DM'
//---BackUp