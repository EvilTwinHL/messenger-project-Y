const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const sqlite3 = require('sqlite3').verbose();
// НОВІ БІБЛІОТЕКИ
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const app = express();
app.use(cors());

// --- БЛОК 1: НАЛАШТУВАННЯ ПАПКИ ДЛЯ ФОТО ---
const UPLOAD_FOLDER = './uploads';
// Якщо папки немає - створюємо її
if (!fs.existsSync(UPLOAD_FOLDER)) {
    fs.mkdirSync(UPLOAD_FOLDER);
}

// Налаштовуємо сховище: куди і під яким іменем зберігати
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, UPLOAD_FOLDER);
    },
    filename: (req, file, cb) => {
        // Генеруємо унікальне ім'я: час + оригінальна назва (щоб файли не перезаписувались)
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, uniqueSuffix + path.extname(file.originalname));
    }
});
const upload = multer({ storage: storage });

// Робимо папку 'uploads' доступною з інтернету
// Тепер файл можна відкрити за адресою: http://IP:3000/uploads/назва_файлу.jpg
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));


// --- БЛОК 2: БАЗА ДАНИХ ---
const db = new sqlite3.Database('./chat.db', (err) => {
    if (err) console.error('Помилка БД:', err.message);
    else {
        console.log('✅ SQLite підключено');
        // Оновлюємо таблицю: додаємо колонку 'type' (text або image)
        // Якщо таблиця вже є, це не спрацює автоматично для старої структури,
        // тому для тестів простіше видалити старий chat.db файл, якщо будуть помилки.
        db.run(`CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            text TEXT,
            sender TEXT,
            type TEXT DEFAULT 'text', 
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )`);
    }
});

const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });

// --- БЛОК 3: МАРШРУТ ЗАВАНТАЖЕННЯ ---
// Телефон стукає сюди, щоб віддати файл
app.post('/upload', upload.single('image'), (req, res) => {
    if (!req.file) {
        return res.status(400).send('Немає файлу');
    }
    // Формуємо посилання на файл
    // УВАГА: Тут ми повертаємо шлях відносно кореня сервера
    const fileUrl = `uploads/${req.file.filename}`;
    
    console.log(`[FILE] Завантажено фото: ${fileUrl}`);
    res.json({ url: fileUrl });
});

// --- БЛОК 4: СОКЕТИ ---
io.on('connection', (socket) => {
    console.log(`[CONN] + ${socket.id}`);

    // Читаємо історію
    db.all("SELECT text, sender, type FROM messages ORDER BY id ASC", [], (err, rows) => {
        if (!err) socket.emit('load_history', rows);
    });

    socket.on('send_message', (data) => {
        // data має вигляд: { text: "...", sender: "...", type: "text" або "image" }
        const msgType = data.type || 'text';
        
        console.log(`[MSG] ${data.sender} (${msgType}): ${data.text}`);

        const stmt = db.prepare("INSERT INTO messages (text, sender, type) VALUES (?, ?, ?)");
        stmt.run(data.text, data.sender, msgType, (err) => {
            if (!err) io.emit('receive_message', { ...data, type: msgType });
        });
        stmt.finalize();
    });
});

app.get('/ping', (req, res) => {
  res.status(200).send('Server is alive!');
});

const PORT = process.env.PORT || 3000;

server.listen(PORT, () => {
    console.log(`✅ Сервер запущено на порті ${PORT}`);
});