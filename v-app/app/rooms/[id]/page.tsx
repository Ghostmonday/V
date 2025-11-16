'use client';

import { useEffect, useState } from 'react';
import { io } from 'socket.io-client';

export default function Room({ params }: { params: { id: string } }) {
  const [messages, setMessages] = useState<any[]>([]);
  const [input, setInput] = useState('');
  const [socket, setSocket] = useState<any>(null);

  useEffect(() => {
    fetch(`/api/rooms/${params.id}/messages`).then(res => res.json()).then(setMessages);
    
    const newSocket = io('http://localhost:3001');
    setSocket(newSocket);
    
    newSocket.emit('join', params.id);
    newSocket.on('message', (msg: any) => setMessages((prev: any[]) => [...prev, msg]));

    return () => {
      newSocket.disconnect();
    };
  }, [params.id]);

  const send = () => {
    if (!input.trim()) return;
    fetch('/api/messaging', { 
      method: 'POST', 
      headers: { 'Content-Type': 'application/json' }, 
      body: JSON.stringify({ roomId: params.id, content: input }) 
    });
    setInput('');
  };

  return (
    <div>
      <h2>Room {params.id}</h2>
      <ul>{messages.map((msg, i) => <li key={i}>{msg.content || msg.content_preview}</li>)}</ul>
      <input value={input} onChange={e => setInput(e.target.value)} onKeyPress={e => e.key === 'Enter' && send()} />
      <button onClick={send}>Send</button>
    </div>
  );
}

