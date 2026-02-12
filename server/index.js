const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
var admin = require("firebase-admin");
var serviceAccount = require("./serviceAccountKey.json");

// --- 🛑 НАЛАШТУВАННЯ ---
// Вставте сюди ТЕ, що скопіювали з консолі (без gs://)
const BUCKET_NAME = "project-y-8df27.firebasestorage.app"; 
// -----------------------

// Ініціалізація з Bucket
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: BUCKET_NAME 
});

const db = admin.firestore();
const bucket = admin.storage().bucket(); // Підключаємось до сховища

const app = express();
app.use(cors());

// Налаштування Multer (тимчасове зберігання файлу перед відправкою в хмару)
const multer = require('multer');
const fs = require('fs');
const upload = multer({ dest: 'uploads/' }); // Тимчасова папка

// --- 📸 НОВА ЛОГІКА ЗАВАНТАЖЕННЯ ---
app.post('/upload', upload.single('image'), async (req, res) => {
    if (!req.file) return res.status(400).send('No file');

    try {
        const localFilePath = req.file.path;
        const remoteFileName = `images/${Date.now()}_${req.file.originalname}`;

        // 1. Завантажуємо в Firebase Storage
        await bucket.upload(localFilePath, {
            destination: remoteFileName,
            metadata: {
                contentType: req.file.mimetype, // Наприклад, image/jpeg
            }
        });

        // 2. Отримуємо публічне посилання (діє до 2030 року)
        const file = bucket.file(remoteFileName);
        const [url] = await file.getSignedUrl({
            action: 'read',
            expires: '03-01-2500' 
        });

        // 3. Видаляємо тимчасовий файл з Render (щоб не засмічувати пам'ять)
        fs.unlinkSync(localFilePath);

        console.log(`✅ Фото завантажено: ${url}`);
        res.json({ url: url });

    } catch (error) {
        console.error("Помилка завантаження:", error);
        res.status(500).send("Upload failed");
    }
});
// -----------------------------------

const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });

const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
    res.send('Chat Server (Firebase DB + Storage) is Running! 🚀');
});

io.on('connection', async (socket) => {
    console.log(`[CONN] Користувач: ${socket.id}`);

    // Завантаження історії
    try {
        const messagesRef = db.collection('messages');
        const snapshot = await messagesRef.orderBy('timestamp', 'asc').limit(50).get();
        const history = [];
        snapshot.forEach(doc => history.push(doc.data()));
        socket.emit('load_history', history);
    } catch (error) {
        console.error("Помилка історії:", error);
    }

    // Отримання повідомлення
    socket.on('send_message', async (data) => {
        const messageData = {
            text: data.text || '',
            sender: data.sender,
            type: data.type || 'text',
            imageUrl: data.imageUrl || null, // Додаємо поле для картинки
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        };
        await db.collection('messages').add(messageData);
        io.emit('receive_message', data); 
    });
});

server.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});