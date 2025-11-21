import { Router, Request, Response } from 'express';
import { authenticateWithCredentials, registerUser } from '../services/user-authentication-service.js';
import { logError, logInfo } from '../shared/logger-shared.js';
import { rateLimit } from '../middleware/rate-limiting/rate-limiter-middleware.js';

const router = Router();

// Rate limiting: 10 attempts per minute for auth endpoints
router.use(rateLimit({ max: 10, windowMs: 60 * 1000 }));

/**
 * POST /api/auth/login
 * Authenticate with username and password
 */
router.post('/login', async (req: Request, res: Response) => {
    try {
        const { username, password } = req.body;

        if (!username || !password) {
            return res.status(400).json({ error: 'Need your username and password' });
        }

        const result = await authenticateWithCredentials(username, password);

        logInfo('User logged in successfully', { username });
        res.json(result);
    } catch (error: any) {
        logError('Login failed', error);
        res.status(401).json({ error: error.message || "Couldn't sign you in" });
    }
});

/**
 * POST /api/auth/register
 * Register new user
 */
router.post('/register', async (req: Request, res: Response) => {
    try {
        const { username, password, ageVerified } = req.body;

        if (!username || !password) {
            return res.status(400).json({ error: 'Need your username and password' });
        }

        const result = await registerUser(username, password, ageVerified);

        logInfo('User registered successfully', { username });
        res.json(result);
    } catch (error: any) {
        logError('Registration failed', error);
        res.status(400).json({ error: error.message || "Couldn't create your account" });
    }
});

export default router;
