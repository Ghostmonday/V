import { Request, Response, NextFunction } from 'express';
import { getCached, setCached, generateETag } from '../../services/cache-service.js';

export function cacheMiddleware(prefix: string) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const key = `${prefix}:${req.url}`;
    const cached = await getCached(key);
    if (cached) {
      const etag = generateETag(cached);
      if (req.headers['if-none-match'] === etag) {
        return res.status(304).end();
      }
      res.set('ETag', etag);
      return res.json(cached);
    }
    res.locals.cacheKey = key;
    next();
  };
}

