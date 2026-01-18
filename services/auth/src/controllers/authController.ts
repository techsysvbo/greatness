import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import * as db from '../db';
import { generateToken } from '../utils/jwt';

export const register = async (req: Request, res: Response) => {
    const { email, password, fullName } = req.body;

    if (!email || !password) {
        return res.status(400).json({ message: 'Email and password are required' });
    }

    try {
        // Check if user exists
        const userCheck = await db.query('SELECT * FROM users WHERE email = $1', [email]);
        if (userCheck.rows.length > 0) {
            return res.status(409).json({ message: 'User already exists' });
        }

        // Hash password
        const hashedPassword = await bcrypt.hash(password, 10);

        // Insert user
        const result = await db.query(
            'INSERT INTO users (email, password_hash, full_name) VALUES ($1, $2, $3) RETURNING id, email, full_name, role',
            [email, hashedPassword, fullName]
        );

        const user = result.rows[0];
        const token = generateToken(user.id, user.email);

        res.status(201).json({
            user: {
                id: user.id,
                email: user.email,
                fullName: user.full_name,
                role: user.role
            },
            token
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
};

export const login = async (req: Request, res: Response) => {
    const { email, password } = req.body;

    try {
        const result = await db.query('SELECT * FROM users WHERE email = $1', [email]);

        if (result.rows.length === 0) {
            return res.status(401).json({ message: 'Invalid credentials' });
        }

        const user = result.rows[0];
        const isMatch = await bcrypt.compare(password, user.password_hash);

        if (!isMatch) {
            return res.status(401).json({ message: 'Invalid credentials' });
        }

        const token = generateToken(user.id, user.email);

        // Don't send password hash
        delete user.password_hash;

        res.json({
            user: {
                id: user.id,
                email: user.email,
                fullName: user.full_name,
                role: user.role
            },
            token
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
};
