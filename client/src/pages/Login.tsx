import { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { useNavigate, Link } from 'react-router-dom';

const Login = () => {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');
    const { login } = useAuth();
    const navigate = useNavigate();

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        try {
            await login(email, password);
            navigate('/profile');
        } catch (err: any) {
            console.error(err);
            setError(err.response?.data?.message || 'Invalid email or password');
        }
    };

    return (
        <div className="auth-container" style={{ maxWidth: '400px', margin: '4rem auto', padding: '2rem', background: 'var(--color-bg-card)', borderRadius: '1rem' }}>
            <h2 style={{ marginBottom: '1.5rem', textAlign: 'center' }}>Welcome Back</h2>
            {error && <div style={{ color: '#ef4444', marginBottom: '1rem', textAlign: 'center' }}>{error}</div>}
            <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                <div>
                    <label style={{ display: 'block', marginBottom: '0.5rem', color: 'var(--color-text-muted)' }}>Email</label>
                    <input
                        type="email"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        required
                        style={{ width: '100%', padding: '0.75rem', borderRadius: '0.5rem', border: '1px solid #334155', background: '#1e293b', color: 'white' }}
                    />
                </div>
                <div>
                    <label style={{ display: 'block', marginBottom: '0.5rem', color: 'var(--color-text-muted)' }}>Password</label>
                    <input
                        type="password"
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                        required
                        style={{ width: '100%', padding: '0.75rem', borderRadius: '0.5rem', border: '1px solid #334155', background: '#1e293b', color: 'white' }}
                    />
                </div>
                <button type="submit" style={{ marginTop: '0.5rem' }}>Log In</button>
            </form>
            <p style={{ marginTop: '1.5rem', textAlign: 'center', color: 'var(--color-text-muted)' }}>
                Don't have an account? <Link to="/api/auth/api/auth/auth/api/auth/auth/register" style={{ color: 'var(--color-primary)' }}>Sign up</Link>
            </p>
        </div>
    );
};

export default Login;
