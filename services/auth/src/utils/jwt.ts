import jwt from 'jsonwebtoken';

const SECRET = process.env.JWT_SECRET || 'default_secret';

export const generateToken = (userId: number, email: string) => {
    return jwt.sign({ userId, email }, SECRET, { expiresIn: '1h' });
};

export const verifyToken = (token: string) => {
    return jwt.verify(token, SECRET);
};
