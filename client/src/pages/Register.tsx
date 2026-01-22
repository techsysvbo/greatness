import { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { useNavigate, Link } from 'react-router-dom';
import api from '../services/api';
import { LOCATION_DATA, COUNTRIES_LIST } from '../constants/locations';

const Register = () => {
    const [fullName, setFullName] = useState('');
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');

    // Location State
    const [country, setCountry] = useState('');
    const [state, setState] = useState('');
    const [city, setCity] = useState('');

    const [error, setError] = useState('');
    const { register } = useAuth();
    const navigate = useNavigate();

    // Derived lists for cascading dropdowns
    const statesList = country && LOCATION_DATA[country] ? Object.keys(LOCATION_DATA[country]) : [];
    const citiesList = country && state && LOCATION_DATA[country]?.[state] ? LOCATION_DATA[country][state] : [];

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        try {
            // 1. Register User
            await register(email, password, fullName);

            // 2. Update Profile with Location Data immediately
            try {
                await api.put('/api/profile/api/profile/profile/me', {
                    country,
                    state,
                    city,
                    profession: '', // Optional defaults
                    interests: ''
                });
            } catch (profileErr) {
                console.error("Failed to sync initial profile data:", profileErr);
                // Continue anyway, as the user is registered.
            }

            navigate('/');
        } catch (err: any) {
            console.error(err);
            setError(err.response?.data?.message || 'Registration failed. Check console for details.');
        }
    };

    return (
        <div className="auth-container" style={{ maxWidth: '400px', margin: '4rem auto', padding: '2rem', background: 'var(--color-bg-card)', borderRadius: '1rem' }}>
            <h2 style={{ marginBottom: '1.5rem', textAlign: 'center' }}>Join the Community</h2>
            {error && <div style={{ color: '#ef4444', marginBottom: '1rem', textAlign: 'center' }}>{error}</div>}
            <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                <div>
                    <label style={{ display: 'block', marginBottom: '0.5rem', color: 'var(--color-text-muted)' }}>Full Name</label>
                    <input
                        type="text"
                        value={fullName}
                        onChange={(e) => setFullName(e.target.value)}
                        required
                        style={{ width: '100%', padding: '0.75rem', borderRadius: '0.5rem', border: '1px solid #334155', background: '#1e293b', color: 'white' }}
                    />
                </div>
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

                {/* Cascading Location Fields */}
                <div>
                    <label style={{ display: 'block', marginBottom: '0.5rem', color: 'var(--color-text-muted)' }}>Country</label>
                    <input
                        list="country-list"
                        value={country}
                        onChange={(e) => {
                            setCountry(e.target.value);
                            setState('');
                            setCity('');
                        }}
                        placeholder="Search Country"
                        required
                        style={{ width: '100%', padding: '0.75rem', borderRadius: '0.5rem', border: '1px solid #334155', background: '#1e293b', color: 'white' }}
                    />
                    <datalist id="country-list">
                        {COUNTRIES_LIST.map(c => <option key={c} value={c} />)}
                    </datalist>
                </div>

                <div>
                    <label style={{ display: 'block', marginBottom: '0.5rem', color: 'var(--color-text-muted)' }}>State / Region</label>
                    <input
                        list="state-list"
                        value={state}
                        onChange={(e) => {
                            setState(e.target.value);
                            setCity('');
                        }}
                        placeholder={statesList.length ? "Select State" : "Enter State"}
                        required
                        style={{ width: '100%', padding: '0.75rem', borderRadius: '0.5rem', border: '1px solid #334155', background: '#1e293b', color: 'white' }}
                    />
                    <datalist id="state-list">
                        {statesList.map(s => <option key={s} value={s} />)}
                    </datalist>
                </div>

                <div>
                    <label style={{ display: 'block', marginBottom: '0.5rem', color: 'var(--color-text-muted)' }}>City</label>
                    <input
                        list="city-list"
                        value={city}
                        onChange={(e) => setCity(e.target.value)}
                        placeholder={citiesList.length ? "Select City" : "Enter City"}
                        required
                        style={{ width: '100%', padding: '0.75rem', borderRadius: '0.5rem', border: '1px solid #334155', background: '#1e293b', color: 'white' }}
                    />
                    <datalist id="city-list">
                        {citiesList.map(c => <option key={c} value={c} />)}
                    </datalist>
                </div>

                <button type="submit" style={{ marginTop: '1rem', padding: '0.75rem', borderRadius: '0.5rem', background: 'var(--color-primary)', color: 'white', border: 'none', cursor: 'pointer', fontWeight: 'bold' }}>
                    Join Us
                </button>
            </form>
            <p style={{ marginTop: '1.5rem', textAlign: 'center', color: 'var(--color-text-muted)' }}>
                Already have an account? <Link to="/login" style={{ color: 'var(--color-primary)' }}>Log in</Link>
            </p>
        </div>
    );
};

export default Register;
