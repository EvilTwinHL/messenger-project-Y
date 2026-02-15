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

// --- 🔐 1. АВТОРИЗАЦІЯ (РЕЄСТРАЦІЯ/ВХІД + АВАТАРКА) ---
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

// --- ЗАВАНТАЖЕННЯ ФОТО ---
app.post('/upload', upload.single('image'), async (req, res) => {
    if (!req.file) return res.status(400).send('No file');

    try {
        const localFilePath = req.file.path;
        // Очищаємо ім'я файлу
        const safeName = req.file.originalname.replace(/[^a-zA-Z0-9.]/g, "_");
        const remoteFileName = `images/${Date.now()}_${safeName}`;

        // 1. Завантажуємо в Firebase Storage
        await bucket.upload(localFilePath, {
            destination: remoteFileName,
            metadata: {
                contentType: req.file.mimetype, 
            }
        });

        // 2. Отримуємо публічне посилання
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
const io = new Server(server, { cors: { origin: "*" },

    maxHttpBufferSize: 6e7 // 10 MB (збільшує ліміт передачі даних)
});

const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
    res.send('Server Running (With Push Filtering) 🚀');
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

    // --- 1. РЕЄСТРАЦІЯ ТОКЕНА ---
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
            console.log(`💾 Збереження токена для ${username || 'Unknown'}: ${token.substring(0, 10)}...`);
            try {
                await db.collection('fcm_tokens').doc(token).set({
                    username: username,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                });
                console.log(`✅ Токен успішно записано в БД`);
            } catch (e) {
                console.error("❌ Помилка запису токена:", e);
            }
        }
    });

    // --- 2. ЗАВАНТАЖЕННЯ ІСТОРІЇ (ОНОВЛЕНО ДЛЯ ID) ---
    try {
        const messagesRef = db.collection('messages');
        
        // 1. Беремо 50 НАЙНОВІШИХ повідомлень
        const snapshot = await messagesRef.orderBy('timestamp', 'desc').limit(50).get();
        
        // 🔥 ЗМІНА: Тепер ми додаємо ID документа до об'єкта повідомлення
        let history = snapshot.docs.map(doc => {
            return {
                id: doc.id, // <--- ВАЖЛИВО: додаємо ID, щоб потім можна було видалити
                ...doc.data()
            };
        });

        // 3. Розвертаємо масив
        history = history.reverse();

        socket.emit('load_history', history);
    } catch (error) {
        console.error("Помилка історії:", error);
    }

    // --- 3. ОТРИМАННЯ ПОВІДОМЛЕННЯ (ОНОВЛЕНО ДЛЯ ID) ---
    socket.on('send_message', async (data) => {
        const messageData = {
            text: data.text || '',
            sender: data.sender,
            senderAvatar: data.senderAvatar || null,
            type: data.type || 'text',
            imageUrl: data.imageUrl || null,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            read: false // 🔥 НОВЕ: По замовчуванню непрочитане
        };

        // А) 🔥 ЗМІНА: Зберігаємо і отримуємо посилання (docRef), щоб знати ID
        const docRef = await db.collection('messages').add(messageData);
        
        // Створюємо об'єкт для відправки клієнтам з реальним ID
        const savedMessage = {
            id: docRef.id, // <--- ID з бази
            ...data,       // Дані від клієнта
            read: false,   // 🔥
            timestamp: new Date().toISOString() // Тимчасовий час для відображення одразу
        };
        
        // Б) Відправляємо всім, хто онлайн (вже з ID!)
        io.emit('receive_message', savedMessage); 

        // В) 🔥 ВІДПРАВЛЯЄМО ПУШ-СПОВІЩЕННЯ
        try {
            const tokensSnapshot = await db.collection('fcm_tokens').get();
            
            const tokens = tokensSnapshot.docs
                .filter(doc => {
                    const tokenData = doc.data();
                    return tokenData.username !== data.sender;
                })
                .map(doc => doc.id);

            if (tokens.length > 0) {
                const payload = {
                    notification: {
                        title: `Нове від ${data.sender}`,
                        body: data.type === 'image' ? '📷 Фото' : data.text,
                    },
                    tokens: tokens,
                };
                
                const response = await admin.messaging().sendEachForMulticast(payload);
                console.log(`🔔 Пуш розіслано: ${response.successCount}`);
            }
        } catch (error) {
            console.error("Помилка розсилки пушів:", error);
        }
    });

    // --- 4. ІНДИКАТОР НАБОРУ ---
    socket.on('typing', (data) => {
        socket.broadcast.emit('display_typing', data);
    });

    // --- 5. 🔥 ВИДАЛЕННЯ ПОВІДОМЛЕННЯ ---
    socket.on('delete_message', async (messageId) => {
        console.log(`🗑️ Запит на видалення повідомлення: ${messageId}`);
        try {
            // 1. Видаляємо з Firebase
            await db.collection('messages').doc(messageId).delete();
            
            // 2. Кажемо всім клієнтам видалити це повідомлення з екрану
            io.emit('message_deleted', messageId);
        } catch (e) {
            console.error("Помилка видалення:", e);
        }
    });

    // --- 6. 🔥 СТАТУС ПРОЧИТАНО (НОВЕ) ---
    socket.on('mark_read', async (data) => {
        // data = { messageId: "...", reader: "UserB" }
        // Або можна просто відправляти сигнал "всі повідомлення прочитані цим користувачем"
        
        console.log(`👀 Хтось прочитав повідомлення`);
        
        // Тут можна оновити конкретне повідомлення в БД, 
        // але для простоти поки просто скажемо всім: "Оновити статус"
        io.emit('message_read_update', data); 
    });

    socket.on('disconnect', () => {
        console.log(`[DISC] Відключено: ${socket.id}`);
    });
});

server.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});

// add function 'real ststus deliverey messege'