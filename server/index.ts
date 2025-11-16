import express from 'express';
import { createClient } from '@supabase/supabase-js';
import { createClient as createRedis } from 'redis';
import { Server } from 'socket.io';
import http from 'http';
import cors from 'cors';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: 'http://localhost:3000',
    methods: ['GET', 'POST']
  }
});

app.use(cors({
  origin: 'http://localhost:3000',
  credentials: true
}));
app.use(express.json());

const supabaseUrl = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || '';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || '';

if (!supabaseUrl || !supabaseKey) {
  console.error('Missing Supabase credentials. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

// Initialize Redis (optional, will work without it)
// eslint-disable-next-line @typescript-eslint/no-unused-vars
let redis: any = null;
if (process.env.REDIS_URL) {
  const redisClient = createRedis({ url: process.env.REDIS_URL });
  redisClient.connect()
    .then(() => {
      redis = redisClient;
      console.log('Redis connected');
    })
    .catch((err: any) => {
      console.warn('Redis connection failed, continuing without Redis:', err.message);
    });
}

app.get('/rooms', async (req, res) => {
  try {
    const { data, error } = await supabase.from('rooms').select('*');
    if (error) throw error;
    res.json(data || []);
  } catch (error: any) {
    console.error('Error fetching rooms:', error);
    res.status(500).json({ error: error.message });
  }
});

app.post('/rooms', async (req, res) => {
  try {
    const { name, title, slug } = req.body;
    const roomData: any = {};
    if (name) roomData.name = name;
    if (title) roomData.title = title;
    if (slug) roomData.slug = slug;
    if (!roomData.title && !roomData.slug && !roomData.name) {
      roomData.title = name || 'New Room';
    }

    const { data, error } = await supabase.from('rooms').insert(roomData).select();
    if (error) throw error;
    res.json(data?.[0] || {});
  } catch (error: any) {
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
    
    if (error) throw error;
    res.json(data || []);
  } catch (error: any) {
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

    const messageData: any = {
      room_id: roomId,
      content_preview: content.substring(0, 512),
      sender_id: senderId || null
    };

    const { data, error } = await supabase
      .from('messages')
      .insert(messageData)
      .select();
    
    if (error) throw error;
    
    const message = data?.[0];
    if (message) {
      io.to(roomId).emit('message', message);
    }
    
    res.json(message || {});
  } catch (error: any) {
    console.error('Error sending message:', error);
    res.status(500).json({ error: error.message });
  }
});

io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);
  
  socket.on('join', (roomId: string) => {
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

