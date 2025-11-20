#!/usr/bin/env tsx

/**
 * Bot Simulation Script
 * Simulates multiple users connecting and interacting with the app
 */

import WebSocket from 'ws';
import fetch from 'node-fetch';
import crypto from 'crypto';

const BASE_URL = process.env.BASE_URL || 'http://localhost:3000';
const WS_URL = BASE_URL.replace('http', 'ws') + '/ws';
const NUM_BOTS = parseInt(process.env.NUM_BOTS || '10');
const MESSAGE_INTERVAL = parseInt(process.env.MESSAGE_INTERVAL || '5000'); // ms

interface BotUser {
    id: string;
    username: string;
    token: string;
    ws?: WebSocket;
    roomId?: string;
}

const bots: BotUser[] = [];

const BOT_NAMES = [
    'AlphaBot', 'BetaBot', 'GammaBot', 'DeltaBot', 'EpsilonBot',
    'ZetaBot', 'EtaBot', 'ThetaBot', 'IotaBot', 'KappaBot',
    'LambdaBot', 'MuBot', 'NuBot', 'XiBot', 'OmicronBot',
    'PiBot', 'RhoBot', 'SigmaBot', 'TauBot', 'UpsilonBot'
];

const SAMPLE_MESSAGES = [
    'Hello everyone! 👋',
    'How is everyone doing today?',
    'This is amazing!',
    'Great to be here!',
    'Anyone want to chat?',
    'What a cool app!',
    'Testing the waters...',
    'Loving the vibes here! ✨',
    'Hey there! 🎉',
    'This is so smooth!',
    'Anyone else excited?',
    'Let\'s get this party started!',
    'Greetings from the bot world! 🤖',
    'Checking in!',
    'What\'s new?'
];

/**
 * Register a bot user
 */
async function registerBot(username: string): Promise<BotUser> {
    try {
        const email = `${username.toLowerCase()}@bots.vibez.app`;
        const password = crypto.randomBytes(16).toString('hex');

        const response = await fetch(`${BASE_URL}/api/auth/register`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                email,
                password,
                username,
            }),
        });

        if (!response.ok) {
            // Try login instead
            const loginResponse = await fetch(`${BASE_URL}/api/auth/login`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ email, password: 'bot-password-123' }),
            });

            if (loginResponse.ok) {
                const data = await loginResponse.json();
                return {
                    id: data.user.id,
                    username,
                    token: data.token,
                };
            }
        }

        const data = await response.json();
        return {
            id: data.user.id,
            username,
            token: data.token,
        };
    } catch (error) {
        console.error(`Failed to register bot ${username}:`, error);
        throw error;
    }
}

/**
 * Connect bot to WebSocket
 */
function connectBot(bot: BotUser): Promise<void> {
    return new Promise((resolve, reject) => {
        try {
            const ws = new WebSocket(`${WS_URL}?token=${bot.token}`);

            ws.on('open', () => {
                console.log(`✅ ${bot.username} connected`);
                bot.ws = ws;
                resolve();
            });

            ws.on('message', (data: WebSocket.Data) => {
                try {
                    const message = JSON.parse(data.toString());
                    if (message.type === 'room_joined') {
                        bot.roomId = message.roomId;
                        console.log(`📍 ${bot.username} joined room ${bot.roomId}`);
                    }
                } catch (err) {
                    // Ignore parse errors
                }
            });

            ws.on('error', (error) => {
                console.error(`❌ ${bot.username} WebSocket error:`, error.message);
            });

            ws.on('close', () => {
                console.log(`🔌 ${bot.username} disconnected`);
                // Attempt reconnect after 5 seconds
                setTimeout(() => {
                    if (bot.ws?.readyState === WebSocket.CLOSED) {
                        connectBot(bot).catch(console.error);
                    }
                }, 5000);
            });

            // Timeout if connection takes too long
            setTimeout(() => {
                if (ws.readyState !== WebSocket.OPEN) {
                    reject(new Error(`Connection timeout for ${bot.username}`));
                }
            }, 10000);
        } catch (error) {
            reject(error);
        }
    });
}

/**
 * Send a random message from a bot
 */
function sendBotMessage(bot: BotUser) {
    if (!bot.ws || bot.ws.readyState !== WebSocket.OPEN) {
        return;
    }

    const message = SAMPLE_MESSAGES[Math.floor(Math.random() * SAMPLE_MESSAGES.length)];
    const roomId = bot.roomId || 'default-room';

    const envelope = {
        type: 'message',
        room_id: roomId,
        payload: {
            content: message,
            type: 'text',
        },
    };

    bot.ws.send(JSON.stringify(envelope));
    console.log(`💬 ${bot.username}: ${message}`);
}

/**
 * Main bot simulation
 */
async function runBotSimulation() {
    console.log('🤖 Starting Bot Simulation...');
    console.log(`📊 Number of bots: ${NUM_BOTS}`);
    console.log(`⏱️  Message interval: ${MESSAGE_INTERVAL}ms`);
    console.log(`🌐 Server: ${BASE_URL}\n`);

    // Register bots
    console.log('📝 Registering bots...');
    for (let i = 0; i < NUM_BOTS; i++) {
        const username = BOT_NAMES[i % BOT_NAMES.length] + (i >= BOT_NAMES.length ? i : '');
        try {
            const bot = await registerBot(username);
            bots.push(bot);
            console.log(`✓ Registered: ${username}`);
        } catch (error) {
            console.error(`✗ Failed to register ${username}`);
        }
    }

    console.log(`\n✅ Registered ${bots.length} bots\n`);

    // Connect bots
    console.log('🔌 Connecting bots to WebSocket...');
    const connectionPromises = bots.map(bot => connectBot(bot));
    await Promise.allSettled(connectionPromises);

    console.log(`\n✅ Connected ${bots.filter(b => b.ws?.readyState === WebSocket.OPEN).length} bots\n`);

    // Start sending messages
    console.log('💬 Starting message simulation...\n');
    setInterval(() => {
        // Pick a random bot to send a message
        const activeBots = bots.filter(b => b.ws?.readyState === WebSocket.OPEN);
        if (activeBots.length > 0) {
            const randomBot = activeBots[Math.floor(Math.random() * activeBots.length)];
            sendBotMessage(randomBot);
        }
    }, MESSAGE_INTERVAL);

    // Keep the process running
    console.log('🎯 Bot simulation running. Press Ctrl+C to stop.\n');
}

// Handle graceful shutdown
process.on('SIGINT', () => {
    console.log('\n\n🛑 Shutting down bots...');
    bots.forEach(bot => {
        if (bot.ws) {
            bot.ws.close();
        }
    });
    process.exit(0);
});

// Run the simulation
runBotSimulation().catch((error) => {
    console.error('❌ Bot simulation failed:', error);
    process.exit(1);
});
