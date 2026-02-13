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

// --- 📱 СХОВИЩЕ ТОКЕНІВ (В пам'яті) ---
let pushTokens = new Set(); 

// --- 🔐 1. АВТОРИЗАЦІЯ (РЕЄСТРАЦІЯ/ВХІД) ---
app.post('/auth', async (req, res) => {
    const { username } = req.body;

    if (!username || username.trim().length === 0) {
        return res.status(400).json({ error: "Ім'я не може бути пустим" });
    }

    try {
        const usersRef = db.collection('users');
        const snapshot = await usersRef.where('username', '==', username).get();

        if (snapshot.empty) {
            // Створюємо нового користувача, якщо такого немає
            const newUser = {
                username: username,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            await usersRef.add(newUser);
            return res.json({ status: 'created', user: newUser });
        } else {
            // Повертаємо існуючого
            const userData = snapshot.docs[0].data();
            return res.json({ status: 'found', user: userData });
        }
    } catch (error) {
        console.error("Auth Error:", error);
        res.status(500).json({ error: "Помилка сервера при вході" });
    }
});

// --- ЗАВАНТАЖЕННЯ ФОТО ---
app.post('/upload', upload.single('image'), async (req, res) => {
    if (!req.file) return res.status(400).send('No file');

    try {
        const localFilePath = req.file.path;
        const remoteFileName = `images/${Date.now()}_${req.file.originalname}`;

        // 1. Завантажуємо в Firebase Storage
        await bucket.upload(localFilePath, {
            destination: remoteFileName,
            metadata: {
                contentType: req.file.mimetype, 
            }
        });

        // 2. Отримуємо публічне посилання (діє до 2500 року)
        const file = bucket.file(remoteFileName);
        const [url] = await file.getSignedUrl({
            action: 'read',
            expires: '03-01-2500' 
        });

        // 3. Видаляємо тимчасовий файл
        fs.unlinkSync(localFilePath);

        res.json({ url: url });

    } catch (error) {
        console.error("Помилка завантаження:", error);
        res.status(500).send("Upload failed");
    }
});

const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });

const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
    res.send('Chat Server (Firebase DB + Storage + Auth) is Running! 🚀');
});

// 🔥 ЗБЕРЕЖЕНО ВАШ PING
app.get('/ping', (req, res) => {
    console.log('pinged');
    res.send('pong');
});

io.on('connection', async (socket) => {
    console.log(`[CONN] Користувач підключився: ${socket.id}`);

    // --- 1. РЕЄСТРАЦІЯ ТОКЕНА ---
    socket.on('register_token', (token) => {
        if(token) {
            pushTokens.add(token);
            console.log(`📲 Токен додано. Активних пристроїв: ${pushTokens.size}`);
        }
    });

    // --- 2. ЗАВАНТАЖЕННЯ ІСТОРІЇ ---
    try {
        const messagesRef = db.collection('messages');
        const snapshot = await messagesRef.orderBy('timestamp', 'asc').limit(50).get();
        const history = [];
        snapshot.forEach(doc => history.push(doc.data()));
        socket.emit('load_history', history);
    } catch (error) {
        console.error("Помилка історії:", error);
    }

    // --- 3. ОТРИМАННЯ ПОВІДОМЛЕННЯ + ПУШ РОЗСИЛКА ---
    socket.on('send_message', async (data) => {
        const messageData = {
            text: data.text || '',
            sender: data.sender,
            type: data.type || 'text',
            imageUrl: data.imageUrl || null,
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        };

        // А) Зберігаємо в базу
        await db.collection('messages').add(messageData);
        
        // Б) Відправляємо всім, хто онлайн у чаті
        io.emit('receive_message', data); 

        // В) 🔥 ВІДПРАВЛЯЄМО ПУШ-СПОВІЩЕННЯ 🔥
        if (pushTokens.size > 0) {
            const tokensArray = Array.from(pushTokens);
            
            // Формуємо повідомлення
            const notificationTitle = `Нове повідомлення від ${data.sender}`;
            const notificationBody = data.type === 'image' ? '📷 Надіслав фото' : data.text;

            const payload = {
                notification: {
                    title: notificationTitle,
                    body: notificationBody,
                },
                tokens: tokensArray,
            };

            try {
                // Використовуємо Multicast для розсилки всім
                const response = await admin.messaging().sendEachForMulticast(payload);
                console.log(`🔔 Пуш розіслано: Успішно ${response.successCount}`);
            } catch (error) {
                console.error("Помилка розсилки пушів:", error);
            }
        }
    });

    socket.on('disconnect', () => {
        console.log(`[DISC] Відключено: ${socket.id}`);
    });
});

server.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});