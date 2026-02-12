const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
// Підключаємо Firebase
var admin = require("firebase-admin");
var serviceAccount = require("./serviceAccountKey.json");

// Ініціалізація Firebase
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore(); // Наша хмарна база

const app = express();
app.use(cors());

// --- ТИМЧАСОВО: Стара логіка для фото (вони все ще будуть зникати на Render) ---
// Пізніше ми підключимо Firebase Storage для фото
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const UPLOAD_FOLDER = './uploads';
if (!fs.existsSync(UPLOAD_FOLDER)) fs.mkdirSync(UPLOAD_FOLDER);
const storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, UPLOAD_FOLDER),
    filename: (req, file, cb) => cb(null, Date.now() + '-' + Math.round(Math.random() * 1E9) + path.extname(file.originalname))
});
const upload = multer({ storage: storage });
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));
app.post('/upload', upload.single('image'), (req, res) => {
    if (!req.file) return res.status(400).send('No file');
    const fileUrl = `uploads/${req.file.filename}`; 
    res.json({ url: fileUrl });
});
// ----------------------------------------------------------------

const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });

const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
    res.send('Chat Server with Firebase is Running! 🔥');
});

io.on('connection', async (socket) => {
    console.log(`[CONN] Користувач підключився: ${socket.id}`);

    // 1. ЗАВАНТАЖЕННЯ ІСТОРІЇ (З FIREBASE)
    try {
        const messagesRef = db.collection('messages');
        // Беремо останні 50 повідомлень, сортуємо за часом
        const snapshot = await messagesRef.orderBy('timestamp', 'asc').limit(50).get();
        
        const history = [];
        snapshot.forEach(doc => {
            history.push(doc.data());
        });
        
        socket.emit('load_history', history);
    } catch (error) {
        console.error("Помилка читання Firebase:", error);
    }

    // 2. ОТРИМАННЯ ПОВІДОМЛЕННЯ
    socket.on('send_message', async (data) => {
        console.log(`[MSG] ${data.sender}: ${data.text}`);

        const messageData = {
            text: data.text,
            sender: data.sender,
            type: data.type || 'text',
            timestamp: admin.firestore.FieldValue.serverTimestamp() // Час сервера Google
        };

        // Зберігаємо в хмару
        await db.collection('messages').add(messageData);

        // Розсилаємо всім (включно з собою)
        io.emit('receive_message', data); 
    });
});

server.listen(PORT, () => {
    console.log(`✅ Сервер Firebase запущено на порті ${PORT}`);
});