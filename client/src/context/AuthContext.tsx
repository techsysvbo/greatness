import React, { createContext, useContext, useState, useEffect } from 'react';
import api from '../services/api';

interface User {
    id: number;
    email: string;
    fullName: string;
    role: string;
}

interface AuthContextType {
    user: User | null;
    token: string | null;
    isAuthenticated: boolean;
    isLoading: boolean;
    login: (email: string, password: string) => Promise<void>;
    register: (email: string, password: string, fullName: string) => Promise<void>;
    logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
    const [user, setUser] = useState<User | null>(null);
    const [token, setToken] = useState<string | null>(localStorage.getItem('token'));
    const [isLoading, setIsLoading] = useState<boolean>(true);

    // Check for existing token and fetch user on mount
    useEffect(() => {
        const initAuth = async () => {
            const storedToken = localStorage.getItem('token');
            const storedUser = localStorage.getItem('user');

            if (storedToken) {
                setToken(storedToken);
                if (storedUser) {
                    try {
                        setUser(JSON.parse(storedUser));
                    } catch (e) {
                        console.error("Failed to parse stored user", e);
                    }
                }

                try {
                    // Optional: validate token or fetch fresh profile
                    await api.get('/profile/me');
                } catch (error: any) {
                    if (error.response?.status !== 404) {
                        // If error is NOT 404 (meaning token might be invalid), logout
                        // But we should use interceptors for 401. 
                        // For now, let's just keep the session if it's 404 (Profile Not Found)
                    }
                }
            }
            setIsLoading(false);
        };

        initAuth();
    }, [token]);

    const login = async (email: string, password: string) => {
        const response = await api.post('/auth/login', { email, password });
        const { user, token } = response.data;

        localStorage.setItem('token', token);
        localStorage.setItem('user', JSON.stringify(user));
        setToken(token);
        setUser(user);
    };

    const register = async (email: string, password: string, fullName: string) => {
        const response = await api.post('/auth/register', { email, password, fullName });
        const { user, token } = response.data;

        localStorage.setItem('token', token);
        localStorage.setItem('user', JSON.stringify(user));
        setToken(token);
        setUser(user);
    };

    const logout = () => {
        localStorage.removeItem('token');
        localStorage.removeItem('user');
        setToken(null);
        setUser(null);
    };

    return (
        <AuthContext.Provider value={{
            user,
            token,
            isAuthenticated: !!token,
            isLoading,
            login,
            register,
            logout
        }}>
            {children}
        </AuthContext.Provider>
    );
};

export const useAuth = () => {
    const context = useContext(AuthContext);
    if (context === undefined) {
        throw new Error('useAuth must be used within an AuthProvider');
    }
    return context;
};
