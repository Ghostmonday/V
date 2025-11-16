'use client';

import { useEffect, useState } from 'react';
import { useUser } from '@clerk/nextjs';

export default function Rooms() {
  const { user } = useUser();
  const [rooms, setRooms] = useState<any[]>([]);

  useEffect(() => {
    if (user) {
      fetch('/api/rooms').then(res => res.json()).then(setRooms);
    }
  }, [user]);

  return (
    <div>
      <h1>Rooms</h1>
      <ul>{rooms.map(room => <li key={room.id}>{room.name || room.title || room.slug}</li>)}</ul>
      <button onClick={() => fetch('/api/rooms', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name: 'New Room' }) })}>Create Room</button>
    </div>
  );
}

