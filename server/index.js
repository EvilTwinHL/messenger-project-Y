const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
var admin = require("firebase-admin");
var serviceAccount = require("./serviceAccountKey.json");

// --- НАЛАШТУВАННЯ ---
const BUCKET_NAME = "project-y-8df27.firebasestorage.app"; 
// --------------------

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

// --- 🔐 1. АВТОРИЗАЦІЯ ---
app.post('/auth', async (req, res) => {
    const { username, avatarUrl } = req.body;

    if (!username || username.trim().length === 0) {
        return res.status(400).json({ error: "Ім'я не може бути пустим" });
    }

    try {
        const usersRef = db.collection('users');
        const snapshot = await usersRef.where('username', '==', username).get();

        if (snapshot.empty) {
            const newUser = {
                username: username,
                avatarUrl: avatarUrl || null,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            await usersRef.add(newUser);
            return res.json({ status: 'created', user: newUser });
        } else {
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
        res.status(500).json({ error: "Помилка сервера" });
    }
});

// --- 📤 ЗАВАНТАЖЕННЯ ФАЙЛІВ ---
app.post('/upload', upload.single('image'), async (req, res) => {
    if (!req.file) return res.status(400).send('No file');
    try {
        const localFilePath = req.file.path;
        // Очищаємо ім'я файлу від спецсимволів
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
        console.error("Upload Error:", error);
        res.status(500).send("Upload failed");
    }
});

const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => res.send('Server Running (Firestore Tokens) 🚀'));
app.get('/ping', (req, res) => res.send('pong'));

// --- 🔌 SOCKET.IO ---
io.on('connection', async (socket) => {
    console.log(`[CONN] ${socket.id}`);

    // 🔥 1. ЗБЕРІГАЄМО ТОКЕН У БАЗУ (FIRESTORE)
    socket.on('register_token', async (token) => {
        if (token) {
            try {
                // Використовуємо токен як ID документа, щоб уникнути дублікатів
                await db.collection('fcm_tokens').doc(token).set({
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                });
                console.log(`💾 Токен збережено в БД`);
            } catch (e) {
                console.error("Error saving token:", e);
            }
        }
    });

    // 2. ІСТОРІЯ ПОВІДОМЛЕНЬ
    try {
        const snapshot = await db.collection('messages').orderBy('timestamp', 'asc').limit(50).get();
        const history = [];
        snapshot.forEach(doc => history.push(doc.data()));
        socket.emit('load_history', history);
    } catch (e) { console.error(e); }

    // 3. ОТРИМАННЯ ПОВІДОМЛЕННЯ
    socket.on('send_message', async (data) => {
        const messageData = {
            text: data.text || '',
            sender: data.sender,
            senderAvatar: data.senderAvatar || null,
            type: data.type || 'text',
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        };

        // А) Зберігаємо повідомлення
        await db.collection('messages').add(messageData);
        io.emit('receive_message', data);

        // Б) 🔥 ЧИТАЄМО ТОКЕНИ З БАЗИ І ВІДПРАВЛЯЄМО ПУШІ
        try {
            const tokensSnapshot = await db.collection('fcm_tokens').get();
            const tokens = tokensSnapshot.docs.map(doc => doc.id); // Беремо ID документів (це і є токени)

            if (tokens.length > 0) {
                const payload = {
                    notification: {
                        title: `Нове від ${data.sender}`,
                        body: data.type === 'image' ? '📷 Фото' : data.text,
                    },
                    tokens: tokens,
                };
                
                const response = await admin.messaging().sendEachForMulticast(payload);
                console.log(`🔔 Пуш розіслано: ${response.successCount}/${tokens.length}`);
                
                // (Опціонально) Видалення неактивних токенів
                if (response.failureCount > 0) {
                    const failedTokens = [];
                    response.responses.forEach((resp, idx) => {
                        if (!resp.success) {
                            failedTokens.push(tokens[idx]);
                        }
                    });
                    // Тут можна додати логіку видалення failedTokens з бази
                }
            }
        } catch (e) {
            console.error("Push Error:", e);
        }
    });
});

server.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});