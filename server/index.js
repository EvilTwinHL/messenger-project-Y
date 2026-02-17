const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
var admin = require("firebase-admin");
var serviceAccount = require("./serviceAccountKey.json");

const BUCKET_NAME = "project-y-8df27.firebasestorage.app";

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: BUCKET_NAME
});

const db = admin.firestore();
const bucket = admin.storage().bucket();

const app = express();
app.use(cors());
app.use(express.json());

const multer = require('multer');
const fs = require('fs');
const upload = multer({ dest: 'uploads/' });

// ============================================================
// 🔐 AUTH — РЕЄСТРАЦІЯ / ВХІД
// ============================================================

// Реєстрація
app.post('/auth/register', async (req, res) => {
    const { username, password } = req.body;
    if (!username || !password) return res.status(400).json({ error: 'Потрібні username та password' });
    if (username.trim().length < 3) return res.status(400).json({ error: 'Мінімум 3 символи' });
    if (password.length < 6) return res.status(400).json({ error: 'Пароль мінімум 6 символів' });

    try {
        const usersRef = db.collection('users');
        const existing = await usersRef.where('username', '==', username.trim().toLowerCase()).get();
        if (!existing.empty) return res.status(409).json({ error: 'Нікнейм вже зайнятий' });

        const passwordHash = await bcrypt.hash(password, 10);
        const token = crypto.randomBytes(32).toString('hex');

        const userData = {
            username: username.trim().toLowerCase(),
            displayName: username.trim(),
            passwordHash,
            token,
            avatarUrl: null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            lastSeen: admin.firestore.FieldValue.serverTimestamp(),
            online: false,
        };

        const docRef = await usersRef.add(userData);
        const { passwordHash: _, ...safeData } = userData;

        res.json({ status: 'created', user: { id: docRef.id, ...safeData }, token });
    } catch (e) {
        console.error('Register error:', e);
        res.status(500).json({ error: 'Помилка сервера' });
    }
});

// Вхід
app.post('/auth/login', async (req, res) => {
    const { username, password } = req.body;
    if (!username || !password) return res.status(400).json({ error: 'Потрібні username та password' });

    try {
        const snapshot = await db.collection('users')
            .where('username', '==', username.trim().toLowerCase()).get();

        if (snapshot.empty) return res.status(401).json({ error: 'Користувача не знайдено' });

        const doc = snapshot.docs[0];
        const userData = doc.data();

        const valid = await bcrypt.compare(password, userData.passwordHash);
        if (!valid) return res.status(401).json({ error: 'Невірний пароль' });

        // Оновлюємо токен при кожному вході
        const token = crypto.randomBytes(32).toString('hex');
        await doc.ref.update({ token, lastSeen: admin.firestore.FieldValue.serverTimestamp() });

        const { passwordHash, ...safeData } = userData;
        res.json({ status: 'ok', user: { id: doc.id, ...safeData }, token });
    } catch (e) {
        console.error('Login error:', e);
        res.status(500).json({ error: 'Помилка сервера' });
    }
});

// Оновити аватарку
app.post('/auth/update-avatar', upload.single('image'), async (req, res) => {
    const { userId, token } = req.body;
    if (!userId || !token || !req.file) return res.status(400).send('Missing data');

    try {
        const userRef = db.collection('users').doc(userId);
        const userDoc = await userRef.get();
        if (!userDoc.exists || userDoc.data().token !== token) return res.status(401).send('Unauthorized');

        const localPath = req.file.path;
        const remoteFileName = `avatars/${userId}_${Date.now()}.jpg`;
        await bucket.upload(localPath, { destination: remoteFileName, metadata: { contentType: 'image/jpeg' } });
        const [url] = await bucket.file(remoteFileName).getSignedUrl({ action: 'read', expires: '03-01-2500' });
        fs.unlinkSync(localPath);

        await userRef.update({ avatarUrl: url });
        res.json({ avatarUrl: url });
    } catch (e) {
        console.error('Avatar error:', e);
        res.status(500).send('Error');
    }
});

// 🔍 Пошук користувачів
app.get('/users/search', async (req, res) => {
    const { q, token, excludeUserId } = req.query;
    if (!q || q.trim().length < 2) return res.json([]);

    try {
        const snapshot = await db.collection('users')
            .orderBy('username')
            .startAt(q.toLowerCase())
            .endAt(q.toLowerCase() + '\uf8ff')
            .limit(20)
            .get();

        const users = snapshot.docs
            .filter(doc => doc.id !== excludeUserId)
            .map(doc => {
                const { passwordHash, token: t, ...safe } = doc.data();
                return { id: doc.id, ...safe };
            });

        res.json(users);
    } catch (e) {
        console.error('Search error:', e);
        res.json([]);
    }
});

// Отримати профіль по id
app.get('/users/:id', async (req, res) => {
    try {
        const doc = await db.collection('users').doc(req.params.id).get();
        if (!doc.exists) return res.status(404).json({ error: 'Not found' });
        const { passwordHash, token, ...safe } = doc.data();
        res.json({ id: doc.id, ...safe });
    } catch (e) {
        res.status(500).json({ error: 'Error' });
    }
});

// ============================================================
// 💬 ЧАТИ — DM і Групи
// ============================================================

// Список чатів користувача
app.get('/chats', async (req, res) => {
    const { userId } = req.query;
    if (!userId) return res.status(400).json({ error: 'userId required' });

    try {
        const snapshot = await db.collection('chats')
            .where('members', 'array-contains', userId)
            .orderBy('lastMessageAt', 'desc')
            .limit(50)
            .get();

        const chats = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        res.json(chats);
    } catch (e) {
        console.error('Get chats error:', e);
        res.json([]);
    }
});

// Створити або отримати DM чат
app.post('/chats/dm', async (req, res) => {
    const { userId, targetUserId } = req.body;
    if (!userId || !targetUserId) return res.status(400).json({ error: 'Missing ids' });

    try {
        // DM ID — завжди сортований: менший id + більший id
        const members = [userId, targetUserId].sort();
        const dmId = `dm_${members[0]}_${members[1]}`;

        const chatRef = db.collection('chats').doc(dmId);
        const chatDoc = await chatRef.get();

        if (!chatDoc.exists) {
            // Отримуємо інфо обох користувачів
            const [u1doc, u2doc] = await Promise.all([
                db.collection('users').doc(userId).get(),
                db.collection('users').doc(targetUserId).get(),
            ]);

            const u1 = u1doc.data() || {};
            const u2 = u2doc.data() || {};

            await chatRef.set({
                type: 'dm',
                members: [userId, targetUserId],
                memberInfo: {
                    [userId]: { displayName: u1.displayName, avatarUrl: u1.avatarUrl || null },
                    [targetUserId]: { displayName: u2.displayName, avatarUrl: u2.avatarUrl || null },
                },
                lastMessage: null,
                lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }

        res.json({ chatId: dmId });
    } catch (e) {
        console.error('DM error:', e);
        res.status(500).json({ error: 'Помилка' });
    }
});

// Створити групу
app.post('/chats/group', async (req, res) => {
    const { creatorId, name, emoji, memberIds } = req.body;
    if (!creatorId || !name || !memberIds?.length) return res.status(400).json({ error: 'Missing data' });

    try {
        const allMembers = [...new Set([creatorId, ...memberIds])];

        // Отримуємо інфо всіх учасників
        const userDocs = await Promise.all(allMembers.map(id => db.collection('users').doc(id).get()));
        const memberInfo = {};
        userDocs.forEach(doc => {
            if (doc.exists) {
                const d = doc.data();
                memberInfo[doc.id] = { displayName: d.displayName, avatarUrl: d.avatarUrl || null };
            }
        });

        const chatData = {
            type: 'group',
            name: name.trim(),
            emoji: emoji || '👥',
            members: allMembers,
            admins: [creatorId],
            memberInfo,
            lastMessage: null,
            lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: creatorId,
        };

        const docRef = await db.collection('chats').add(chatData);
        res.json({ chatId: docRef.id, ...chatData });
    } catch (e) {
        console.error('Group error:', e);
        res.status(500).json({ error: 'Помилка' });
    }
});

// ============================================================
// 📤 UPLOADS
// ============================================================

app.post('/upload', upload.single('image'), async (req, res) => {
    if (!req.file) return res.status(400).send('No file');
    try {
        const localPath = req.file.path;
        const remoteFileName = `images/${Date.now()}_${req.file.originalname.replace(/[^a-zA-Z0-9.]/g, '_')}`;
        await bucket.upload(localPath, { destination: remoteFileName, metadata: { contentType: req.file.mimetype } });
        const [url] = await bucket.file(remoteFileName).getSignedUrl({ action: 'read', expires: '03-01-2500' });
        fs.unlinkSync(localPath);
        res.json({ url });
    } catch (e) { res.status(500).send('Upload failed'); }
});

app.post('/upload-audio', upload.single('audio'), async (req, res) => {
    if (!req.file) return res.status(400).send('No file');
    try {
        const localPath = req.file.path;
        const remoteFileName = `audio/${Date.now()}.aac`;
        await bucket.upload(localPath, { destination: remoteFileName, metadata: { contentType: req.file.mimetype || 'audio/aac' } });
        const [url] = await bucket.file(remoteFileName).getSignedUrl({ action: 'read', expires: '03-01-2500' });
        fs.unlinkSync(localPath);
        res.json({ url });
    } catch (e) { res.status(500).send('Audio upload failed'); }
});

app.post('/upload-file', upload.single('file'), async (req, res) => {
    if (!req.file) return res.status(400).send('No file');
    try {
        const localPath = req.file.path;
        const originalName = req.file.originalname || 'file';
        const remoteFileName = `files/${Date.now()}_${originalName.replace(/[^a-zA-Z0-9._-]/g, '_')}`;
        await bucket.upload(localPath, { destination: remoteFileName, metadata: { contentType: req.file.mimetype } });
        const [url] = await bucket.file(remoteFileName).getSignedUrl({ action: 'read', expires: '03-01-2500' });
        fs.unlinkSync(localPath);
        res.json({ url, fileName: originalName, fileSize: req.file.size, mimeType: req.file.mimetype });
    } catch (e) { res.status(500).send('File upload failed'); }
});

// ============================================================
// SOCKET.IO
// ============================================================

const server = http.createServer(app);
const io = new Server(server, { cors: { origin: '*' }, maxHttpBufferSize: 6e7 });
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => res.send('Messenger Private v4 🔐'));
app.get('/ping', (req, res) => res.send('pong'));

// socketId → { userId, username, avatarUrl, chatId }
const onlineUsers = new Map();

// Завантажити повідомлення чату
async function loadChatHistory(chatId, socket) {
    try {
        const snapshot = await db.collection('chats').doc(chatId)
            .collection('messages')
            .orderBy('timestamp', 'desc')
            .limit(200)
            .get();
        const history = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })).reverse();
        socket.emit('load_history', history);
    } catch (e) {
        console.error('History error:', e);
        socket.emit('load_history', []);
    }
}

io.on('connection', (socket) => {
    console.log(`[CONN] ${socket.id}`);

    // --- АВТОРИЗАЦІЯ SOCKET ---
    socket.on('authenticate', async ({ userId, token, chatId }) => {
        try {
            const userDoc = await db.collection('users').doc(userId).get();
            if (!userDoc.exists || userDoc.data().token !== token) {
                socket.emit('auth_error', 'Invalid token');
                return;
            }
            const userData = userDoc.data();

            // Зберігаємо стан
            onlineUsers.set(socket.id, {
                userId, token,
                username: userData.displayName,
                avatarUrl: userData.avatarUrl,
                chatId: chatId || null,
            });

            // Оновлюємо статус online
            await userDoc.ref.update({ online: true, lastSeen: admin.firestore.FieldValue.serverTimestamp() });

            socket.emit('authenticated', { ok: true });

            // Якщо є chatId — одразу підключаємо
            if (chatId) {
                await _joinChat(socket, userId, chatId);
            }
        } catch (e) {
            console.error('Auth socket error:', e);
        }
    });

    // --- ПРИЄДНАТИСЬ ДО ЧАТУ ---
    socket.on('join_chat', async ({ chatId }) => {
        const user = onlineUsers.get(socket.id);
        if (!user) return;

        // Покинути попередній чат
        if (user.chatId) socket.leave(user.chatId);

        await _joinChat(socket, user.userId, chatId);
        user.chatId = chatId;
    });

    async function _joinChat(socket, userId, chatId) {
        // Перевіряємо чи є user учасником
        const chatDoc = await db.collection('chats').doc(chatId).get();
        if (!chatDoc.exists) { socket.emit('error', 'Chat not found'); return; }
        if (!chatDoc.data().members.includes(userId)) { socket.emit('error', 'Not a member'); return; }

        socket.join(chatId);

        // Онлайн учасники
        const onlineInChat = getOnlineInChat(chatId);
        io.to(chatId).emit('online_users', onlineInChat);

        // Завантажуємо историю
        await loadChatHistory(chatId, socket);
    }

    // --- НАДІСЛАТИ ПОВІДОМЛЕННЯ ---
    socket.on('send_message', async (data) => {
        const user = onlineUsers.get(socket.id);
        if (!user) return;

        const chatId = data.chatId || user.chatId;
        if (!chatId) return;

        const messageData = {
            text: data.text || '',
            senderId: user.userId,
            sender: user.username,
            senderAvatar: user.avatarUrl || null,
            type: data.type || 'text',
            replyTo: data.replyTo || null,
            audioUrl: data.audioUrl || null,
            audioDuration: data.audioDuration || null,
            fileUrl: data.fileUrl || null,
            fileName: data.fileName || null,
            fileSize: data.fileSize || null,
            fileMime: data.fileMime || null,
            latitude: data.latitude || null,
            longitude: data.longitude || null,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            readBy: [user.userId],
        };

        const chatRef = db.collection('chats').doc(chatId);
        const docRef = await chatRef.collection('messages').add(messageData);

        // Оновлюємо lastMessage в чаті
        let preview = data.text;
        if (data.type === 'image') preview = '📷 Фото';
        else if (data.type === 'voice') preview = '🎤 Голосове';
        else if (data.type === 'file') preview = `📎 ${data.fileName || 'Файл'}`;
        else if (data.type === 'location') preview = '📍 Локація';

        await chatRef.update({
            lastMessage: { text: preview, sender: user.username, senderId: user.userId },
            lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const savedMessage = {
            id: docRef.id,
            ...messageData,
            timestamp: new Date().toISOString(),
        };

        io.to(chatId).emit('receive_message', savedMessage);

        // Push для офлайн учасників
        try {
            const chatDoc = await chatRef.get();
            const members = chatDoc.data()?.members || [];
            const offlineMembers = members.filter(id => id !== user.userId);

            if (offlineMembers.length > 0) {
                const tokenDocs = await Promise.all(
                    offlineMembers.map(id =>
                        db.collection('fcm_tokens').where('userId', '==', id).get()
                    )
                );

                const tokens = [];
                tokenDocs.forEach(snap => snap.docs.forEach(d => tokens.push(d.id)));

                if (tokens.length > 0) {
                    const chatName = chatDoc.data()?.type === 'group'
                        ? `[${chatDoc.data()?.name || 'Група'}] ${user.username}`
                        : user.username;

                    await admin.messaging().sendEachForMulticast({
                        notification: { title: chatName, body: preview || '...' },
                        tokens,
                    });
                }
            }
        } catch (e) { console.error('Push error:', e); }
    });

    // --- TYPING ---
    socket.on('typing', ({ chatId }) => {
        const user = onlineUsers.get(socket.id);
        if (!user) return;
        socket.to(chatId || user.chatId).emit('display_typing', { username: user.username });
    });

    // --- ВИДАЛИТИ ---
    socket.on('delete_message', async ({ messageId, chatId }) => {
        const user = onlineUsers.get(socket.id);
        if (!user) return;
        const room = chatId || user.chatId;
        try {
            await db.collection('chats').doc(room).collection('messages').doc(messageId).delete();
            io.to(room).emit('message_deleted', messageId);
        } catch (e) { console.error('Delete error:', e); }
    });

    // --- РЕДАГУВАТИ ---
    socket.on('edit_message', async ({ messageId, newText, chatId }) => {
        const user = onlineUsers.get(socket.id);
        if (!user) return;
        const room = chatId || user.chatId;
        try {
            const ref = db.collection('chats').doc(room).collection('messages').doc(messageId);
            const doc = await ref.get();
            if (!doc.exists || doc.data().senderId !== user.userId) return;
            await ref.update({ text: newText, edited: true, editedAt: admin.firestore.FieldValue.serverTimestamp() });
            io.to(room).emit('message_edited', { messageId, newText, edited: true });
        } catch (e) { console.error('Edit error:', e); }
    });

    // --- РЕАКЦІЯ ---
    socket.on('add_reaction', async ({ messageId, emoji, chatId }) => {
        const user = onlineUsers.get(socket.id);
        if (!user) return;
        const room = chatId || user.chatId;
        try {
            const ref = db.collection('chats').doc(room).collection('messages').doc(messageId);
            const doc = await ref.get();
            if (!doc.exists) return;
            const reactions = doc.data().reactions || {};
            if (!reactions[emoji]) reactions[emoji] = [];
            const idx = reactions[emoji].indexOf(user.userId);
            if (idx === -1) reactions[emoji].push(user.userId);
            else {
                reactions[emoji].splice(idx, 1);
                if (!reactions[emoji].length) delete reactions[emoji];
            }
            await ref.update({ reactions });
            io.to(room).emit('reaction_updated', { messageId, reactions });
        } catch (e) { console.error('Reaction error:', e); }
    });

    // --- MARK READ ---
    socket.on('mark_read', async ({ chatId, messageId }) => {
        const user = onlineUsers.get(socket.id);
        if (!user) return;
        const room = chatId || user.chatId;
        try {
            if (messageId) {
                const ref = db.collection('chats').doc(room).collection('messages').doc(messageId);
                await ref.update({ readBy: admin.firestore.FieldValue.arrayUnion(user.userId) });
            }
            socket.to(room).emit('message_read_update', { readBy: user.userId });
        } catch (e) { }
    });

    // --- FCM TOKEN ---
    socket.on('register_token', async (data) => {
        const user = onlineUsers.get(socket.id);
        const token = typeof data === 'string' ? data : data?.token;
        const userId = user?.userId || data?.userId;
        if (token && userId) {
            await db.collection('fcm_tokens').doc(token).set({
                userId,
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        }
    });

    // --- DISCONNECT ---
    socket.on('disconnect', async () => {
        const user = onlineUsers.get(socket.id);
        if (user) {
            try {
                await db.collection('users').doc(user.userId).update({
                    online: false,
                    lastSeen: admin.firestore.FieldValue.serverTimestamp()
                });
                if (user.chatId) io.to(user.chatId).emit('online_users', getOnlineInChat(user.chatId));
            } catch (e) { }
            onlineUsers.delete(socket.id);
        }
        console.log(`[DISC] ${socket.id}`);
    });
});

function getOnlineInChat(chatId) {
    const users = [];
    for (const [, u] of onlineUsers) {
        if (u.chatId === chatId) users.push(u.username);
    }
    return [...new Set(users)];
}

server.listen(PORT, () => console.log(`Private Messenger Server on port ${PORT} 🔐`));

// add function 'real ststus deliverey messege'