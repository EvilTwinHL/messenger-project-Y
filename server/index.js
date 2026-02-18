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
const bucket = admin.storage().bucket();

const app = express();
app.use(cors());
app.use(express.json());

// Налаштування Multer
const multer = require('multer');
const fs = require('fs');
const upload = multer({ dest: 'uploads/' });

// ==============================================
// 🔐 FIREBASE AUTH ENDPOINTS
// ==============================================

// 🔥 ПОШУК КОРИСТУВАЧІВ
app.get('/api/search-users', async (req, res) => {
  const query = req.query.q?.toLowerCase() || '';
  const currentUserId = req.query.userId;
  
  try {
    const usersRef = db.collection('users');
    const snapshot = await usersRef.get();
    
    const users = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      // Виключаємо поточного користувача з результатів
      if (doc.id !== currentUserId && data.username?.toLowerCase().includes(query)) {
        users.push({ 
          id: doc.id, 
          username: data.username,
          email: data.email,
          avatarUrl: data.avatarUrl || null,
          online: data.online || false
        });
      }
    });
    
    res.json(users);
  } catch (error) {
    console.error("Search error:", error);
    res.status(500).json({ error: 'Search failed' });
  }
});

// 🔥 СТВОРЕННЯ/ОТРИМАННЯ DM КІМНАТИ
app.post('/api/get-or-create-dm', async (req, res) => {
  const { userId1, userId2 } = req.body;

  if (!userId1 || !userId2) {
    return res.status(400).json({ error: 'Missing userId1 or userId2' });
  }

  try {
    // Перевіряємо, чи вже існує DM між цими користувачами
    const roomsRef = db.collection('rooms');
    const snapshot = await roomsRef
      .where('type', '==', 'direct')
      .where('members', 'array-contains', userId1)
      .get();

    let existingRoom = null;
    snapshot.forEach(doc => {
      const data = doc.data();
      if (data.members.includes(userId2)) {
        existingRoom = { id: doc.id, ...data };
      }
    });

    if (existingRoom) {
      return res.json({ roomId: existingRoom.id, room: existingRoom });
    }

    // Створюємо новий DM
    const user1Doc = await db.collection('users').doc(userId1).get();
    const user2Doc = await db.collection('users').doc(userId2).get();

    if (!user1Doc.exists || !user2Doc.exists) {
      return res.status(404).json({ error: 'One or both users not found' });
    }

    const user1Data = user1Doc.data();
    const user2Data = user2Doc.data();

    const newRoom = {
      type: 'direct',
      name: `${user1Data.username} & ${user2Data.username}`,
      members: [userId1, userId2],
      membersData: {
        [userId1]: {
          username: user1Data.username,
          avatarUrl: user1Data.avatarUrl || null,
          email: user1Data.email || null
        },
        [userId2]: {
          username: user2Data.username,
          avatarUrl: user2Data.avatarUrl || null,
          email: user2Data.email || null
        }
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: userId1,
      lastMessage: null
    };

    const docRef = await roomsRef.add(newRoom);
    console.log(`✅ Created DM room: ${docRef.id}`);
    
    res.json({ roomId: docRef.id, room: { id: docRef.id, ...newRoom } });

  } catch (error) {
    console.error("Error creating DM:", error);
    res.status(500).json({ error: 'Failed to create DM' });
  }
});

// 🔥 ОТРИМАННЯ ВСІХ КІМНАТ КОРИСТУВАЧА
app.get('/api/user-rooms/:userId', async (req, res) => {
  const { userId } = req.params;

  try {
    const roomsRef = db.collection('rooms');
    const snapshot = await roomsRef
      .where('members', 'array-contains', userId)
      .orderBy('lastMessage.timestamp', 'desc')
      .get();

    const rooms = [];
    snapshot.forEach(doc => {
      rooms.push({ id: doc.id, ...doc.data() });
    });

    res.json(rooms);
  } catch (error) {
    console.error("Error fetching rooms:", error);
    res.status(500).json({ error: 'Failed to fetch rooms' });
  }
});

// ==============================================
// 📤 ЗАВАНТАЖЕННЯ ФАЙЛІВ
// ==============================================

// --- ЗАВАНТАЖЕННЯ ФОТО ---
app.post('/upload', upload.single('image'), async (req, res) => {
    if (!req.file) return res.status(400).send('No file');

    try {
        const localFilePath = req.file.path;
        const safeName = req.file.originalname.replace(/[^a-zA-Z0-9.]/g, "_");
        const remoteFileName = `images/${Date.now()}_${safeName}`;

        await bucket.upload(localFilePath, {
            destination: remoteFileName,
            metadata: {
                contentType: req.file.mimetype, 
            }
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

// --- 🎤 ЗАВАНТАЖЕННЯ АУДІО ---
app.post('/upload-audio', upload.single('audio'), async (req, res) => {
    if (!req.file) return res.status(400).send('No audio file');

    try {
        const localFilePath = req.file.path;
        const safeName = req.file.originalname.replace(/[^a-zA-Z0-9.]/g, "_");
        const remoteFileName = `audio/${Date.now()}_${safeName}`;

        await bucket.upload(localFilePath, {
            destination: remoteFileName,
            metadata: {
                contentType: req.file.mimetype || 'audio/aac',
            }
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

// --- 📁 ЗАВАНТАЖЕННЯ ФАЙЛІВ (DOCS, PDF) ---
app.post('/upload-file', upload.single('file'), async (req, res) => {
    if (!req.file) return res.status(400).send('No file');

    try {
        const localFilePath = req.file.path;
        const safeName = req.file.originalname.replace(/[^a-zA-Z0-9.]/g, "_");
        const remoteFileName = `files/${Date.now()}_${safeName}`;

        await bucket.upload(localFilePath, {
            destination: remoteFileName,
            metadata: {
                contentType: req.file.mimetype,
            }
        });

        const file = bucket.file(remoteFileName);
        const [url] = await file.getSignedUrl({
            action: 'read',
            expires: '03-01-2500'
        });

        fs.unlinkSync(localFilePath);
        res.json({ url: url, filename: req.file.originalname });

    } catch (error) {
        console.error("Помилка завантаження файлу:", error);
        res.status(500).send("File upload failed");
    }
});

// ==============================================
// 🔌 SOCKET.IO - REAL-TIME
// ==============================================

const server = http.createServer(app);
const io = new Server(server, { 
  cors: { origin: "*" },
  maxHttpBufferSize: 6e7
});

const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
    res.send('Server Running with Firebase Auth & Rooms 🚀');
});

app.get('/ping', (req, res) => {
    console.log('pinged');
    res.send('pong');
});

// Зберігаємо userId для кожного socket
const socketUsers = new Map();

io.on('connection', async (socket) => {
    console.log(`[CONN] Socket підключився: ${socket.id}`);

    // 🔥 Логи з телефону
    socket.on('debug_log', (msg) => {
        console.log(`📱 CLIENT LOG [${socket.id}]:`, msg);
    });

    // 🔥 1. JOIN ROOM
    socket.on('join_room', async ({ roomId, userId, username }) => {
        socket.join(roomId);
        socketUsers.set(socket.id, userId);
        
        console.log(`✅ User ${username} (${userId}) joined room ${roomId}`);

        // Оновлюємо online статус
        try {
            await db.collection('users').doc(userId).update({
                online: true,
                lastSeen: admin.firestore.FieldValue.serverTimestamp()
            });
        } catch (e) {
            console.error("Error updating online status:", e);
        }

        // Завантажуємо історію кімнати
        try {
            const messagesRef = db.collection('messages');
            const snapshot = await messagesRef
                .where('roomId', '==', roomId)
                .orderBy('timestamp', 'desc')
                .limit(300)
                .get();

            let history = snapshot.docs.map(doc => ({
                id: doc.id,
                ...doc.data()
            }));

            history = history.reverse();
            socket.emit('load_history', history);
        } catch (error) {
            console.error("Error loading history:", error);
        }
    });

    // 🔥 2. SEND MESSAGE
    socket.on('send_message', async (data) => {
        console.log(`📨 Message from ${data.sender} to room ${data.roomId}`);
        
        const messageData = {
            roomId: data.roomId,
            text: data.text || '',
            senderId: data.senderId,
            sender: data.sender,
            senderAvatar: data.senderAvatar || null,
            type: data.type || 'text',
            imageUrl: data.imageUrl || null,
            audioUrl: data.audioUrl || null,
            audioDuration: data.audioDuration || null,
            fileUrl: data.fileUrl || null,
            fileName: data.fileName || null,
            location: data.location || null,
            replyTo: data.replyTo || null,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            reactions: {},
            edited: false
        };

        try {
            const docRef = await db.collection('messages').add(messageData);

            const savedMessage = {
                id: docRef.id,
                ...data,
                timestamp: new Date().toISOString()
            };

            // Відправляємо ТІЛЬКИ в цю кімнату
            io.to(data.roomId).emit('receive_message', savedMessage);

            // Оновлюємо lastMessage в rooms
            await db.collection('rooms').doc(data.roomId).update({
                'lastMessage.text': data.text || '📎',
                'lastMessage.sender': data.sender,
                'lastMessage.timestamp': admin.firestore.FieldValue.serverTimestamp()
            });

            // 🔔 PUSH-СПОВІЩЕННЯ
            try {
                const roomDoc = await db.collection('rooms').doc(data.roomId).get();
                if (!roomDoc.exists) return;

                const roomData = roomDoc.data();
                const otherMembers = roomData.members.filter(m => m !== data.senderId);
                
                if (otherMembers.length === 0) return;

                const tokens = [];
                for (const memberId of otherMembers) {
                    const userDoc = await db.collection('users').doc(memberId).get();
                    if (userDoc.exists && userDoc.data().fcmToken) {
                        tokens.push(userDoc.data().fcmToken);
                    }
                }

                if (tokens.length > 0) {
                    let body = data.text;
                    if (data.type === 'image') body = '📷 Фото';
                    else if (data.type === 'audio') body = '🎤 Голосове повідомлення';
                    else if (data.type === 'file') body = `📁 ${data.fileName || 'Файл'}`;
                    else if (data.type === 'location') body = '📍 Локація';

                    await admin.messaging().sendEachForMulticast({
                        notification: {
                            title: `${data.sender} в ${roomData.name}`,
                            body: body
                        },
                        tokens
                    });
                    console.log(`🔔 Push sent to ${tokens.length} users`);
                }
            } catch (e) {
                console.error("Push error:", e);
            }
        } catch (error) {
            console.error("Error sending message:", error);
        }
    });

    // 🔥 3. TYPING INDICATOR
    socket.on('typing', (data) => {
        socket.to(data.roomId).emit('display_typing', data);
    });

    // 🔥 4. DELETE MESSAGE
    socket.on('delete_message', async ({ messageId, roomId }) => {
        console.log(`🗑️ Delete message: ${messageId}`);
        try {
            await db.collection('messages').doc(messageId).delete();
            io.to(roomId).emit('message_deleted', messageId);
        } catch (e) {
            console.error("Delete error:", e);
        }
    });

    // 🔥 5. MARK READ
    socket.on('mark_read', async (data) => {
        console.log(`👀 Mark read in room ${data.roomId}`);
        io.to(data.roomId).emit('message_read_update', data);
    });

    // 🔥 6. ADD REACTION
    socket.on('add_reaction', async ({ messageId, emoji, username, userId, roomId }) => {
        try {
            const messageRef = db.collection('messages').doc(messageId);
            const messageDoc = await messageRef.get();
            
            if (!messageDoc.exists) return;
            
            const messageData = messageDoc.data();
            const currentReactions = messageData.reactions || {};
            
            if (!currentReactions[emoji]) {
                currentReactions[emoji] = [];
            }
            
            const userIndex = currentReactions[emoji].indexOf(username);
            if (userIndex === -1) {
                currentReactions[emoji].push(username);
            } else {
                currentReactions[emoji].splice(userIndex, 1);
                if (currentReactions[emoji].length === 0) {
                    delete currentReactions[emoji];
                }
            }
            
            await messageRef.update({ reactions: currentReactions });
            
            io.to(roomId).emit('reaction_updated', {
                messageId,
                reactions: currentReactions
            });
        } catch (error) {
            console.error("Reaction error:", error);
        }
    });

    // 🔥 7. EDIT MESSAGE
    socket.on('edit_message', async ({ messageId, newText, username, userId, roomId }) => {
        console.log(`✏️ Edit message: ${messageId}`);
        try {
            const messageRef = db.collection('messages').doc(messageId);
            const messageDoc = await messageRef.get();
            
            if (!messageDoc.exists) {
                socket.emit('error', { message: 'Повідомлення не знайдено' });
                return;
            }
            
            const messageData = messageDoc.data();
            
            if (messageData.senderId !== userId) {
                socket.emit('error', { message: 'Ви не можете редагувати це повідомлення' });
                return;
            }
            
            await messageRef.update({
                text: newText,
                edited: true,
                editedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            
            io.to(roomId).emit('message_edited', {
                messageId,
                newText,
                edited: true
            });
            
            console.log(`✅ Message edited`);
        } catch (error) {
            console.error("Edit error:", error);
            socket.emit('error', { message: 'Помилка редагування' });
        }
    });

    // 🔥 8. REGISTER FCM TOKEN
    socket.on('register_token', async (data) => {
        let token = "";
        let userId = null;

        if (typeof data === 'string') {
            token = data;
        } else if (typeof data === 'object' && data.token) {
            token = data.token;
            userId = data.userId;
        }

        if (token && userId) {
            console.log(`💾 Saving FCM token for user ${userId}`);
            try {
                await db.collection('users').doc(userId).update({
                    fcmToken: token,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                });
                console.log(`✅ FCM token saved`);
            } catch (e) {
                console.error("❌ Error saving FCM token:", e);
            }
        }
    });

    // 🔥 9. DISCONNECT
    socket.on('disconnect', async () => {
        const userId = socketUsers.get(socket.id);
        
        if (userId) {
            try {
                await db.collection('users').doc(userId).update({
                    online: false,
                    lastSeen: admin.firestore.FieldValue.serverTimestamp()
                });
            } catch (e) {
                console.error("Error updating offline status:", e);
            }
            
            socketUsers.delete(socket.id);
        }
        
        console.log(`[DISC] Socket відключився: ${socket.id}`);
    });
});

server.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
});
