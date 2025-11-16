const BACKEND_URL = process.env.NEXT_PUBLIC_BACKEND_URL || 'http://localhost:3001';

export async function GET(
  request: Request,
  { params }: { params: { id: string } }
) {
  const res = await fetch(`${BACKEND_URL}/rooms/${params.id}/messages`, {
    cache: 'no-store',
  });
  const data = await res.json();
  return Response.json(data);
}

