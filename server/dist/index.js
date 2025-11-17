"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const supabase_js_1 = require("@supabase/supabase-js");
const redis_1 = require("redis");
const socket_io_1 = require("socket.io");
const http_1 = __importDefault(require("http"));
const cors_1 = __importDefault(require("cors"));
const dotenv_1 = __importDefault(require("dotenv"));
dotenv_1.default.config();
const app = (0, express_1.default)();
const server = http_1.default.createServer(app);
const io = new socket_io_1.Server(server, {
    cors: {
        origin: 'http://localhost:3000',
        methods: ['GET', 'POST']
    }
});
app.use((0, cors_1.default)({
    origin: 'http://localhost:3000',
    credentials: true
}));
app.use(express_1.default.json());
const supabaseUrl = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || '';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || '';
if (!supabaseUrl || !supabaseKey) {
    console.error('Missing Supabase credentials. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY');
    process.exit(1);
}
const supabase = (0, supabase_js_1.createClient)(supabaseUrl, supabaseKey);
// Initialize Redis (optional, will work without it)
let redis = null;
if (process.env.REDIS_URL) {
    const redisClient = (0, redis_1.createClient)({ url: process.env.REDIS_URL });
    redisClient.connect()
        .then(() => {
        redis = redisClient;
        console.log('Redis connected');
    })
        .catch((err) => {
        console.warn('Redis connection failed, continuing without Redis:', err.message);
    });
}
app.get('/rooms', async (req, res) => {
    try {
        const { data, error } = await supabase.from('rooms').select('*');
        if (error)
            throw error;
        res.json(data || []);
    }
    catch (error) {
        console.error('Error fetching rooms:', error);
        res.status(500).json({ error: error.message });
    }
});
app.post('/rooms', async (req, res) => {
    try {
        const { name, title, slug } = req.body;
        const roomData = {};
        if (name)
            roomData.name = name;
        if (title)
            roomData.title = title;
        if (slug)
            roomData.slug = slug;
        if (!roomData.title && !roomData.slug && !roomData.name) {
            roomData.title = name || 'New Room';
        }
        const { data, error } = await supabase.from('rooms').insert(roomData).select();
        if (error)
            throw error;
        res.json(data?.[0] || {});
    }
    catch (error) {
        console.error('Error creating room:', error);
        res.status(500).json({ error: error.message });
    }
});
app.get('/rooms/:id/messages', async (req, res) => {
    try {
        const { id } = req.params;
        const { data, error } = await supabase
            .from('messages')
            .select('*')
            .eq('room_id', id)
            .order('created_at', { ascending: false })
            .limit(50);
        if (error)
            throw error;
        res.json(data || []);
    }
    catch (error) {
        console.error('Error fetching messages:', error);
        res.status(500).json({ error: error.message });
    }
});
app.post('/messaging', async (req, res) => {
    try {
        const { roomId, content, senderId } = req.body;
        if (!roomId || !content) {
            return res.status(400).json({ error: 'roomId and content are required' });
        }
        const messageData = {
            room_id: roomId,
            content_preview: content.substring(0, 512),
            sender_id: senderId || null
        };
        const { data, error } = await supabase
            .from('messages')
            .insert(messageData)
            .select();
        if (error)
            throw error;
        const message = data?.[0];
        if (message) {
            io.to(roomId).emit('message', message);
        }
        res.json(message || {});
    }
    catch (error) {
        console.error('Error sending message:', error);
        res.status(500).json({ error: error.message });
    }
});
io.on('connection', (socket) => {
    console.log('Client connected:', socket.id);
    socket.on('join', (roomId) => {
        socket.join(roomId);
        console.log(`Socket ${socket.id} joined room ${roomId}`);
    });
    socket.on('disconnect', () => {
        console.log('Client disconnected:', socket.id);
    });
});
const PORT = process.env.PORT || 3001;
server.listen(PORT, () => {
    console.log(`Backend server running on port ${PORT}`);
});
