import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import api from '../services/api';

interface Event {
    id: number;
    title: string;
    date: string;
    location: string;
}

interface Interest {
    id: number;
    name: string;
}

const Home = () => {
    const { isAuthenticated, user } = useAuth();
    const [events, setEvents] = useState<Event[]>([]);
    const [interests, setInterests] = useState<Interest[]>([]);
    const [profile, setProfile] = useState<any>(null);
    const [loading, setLoading] = useState(false);

    useEffect(() => {
        const fetchRecommendations = async () => {
            if (isAuthenticated && user) {
                setLoading(true);
                try {
                    // Fetch profile to get zipCode and profession for recommendations
                    // Ideally this info should be in 'user' context or fetched once. 
                    // For now, we'll assume we might need to rely on the profile endpoint or passed user data.
                    // Let's try to fetch suggestions directly using the AI proxy.
                    // Note: We need to pass query params. 
                    // Since we don't have zip/profession in 'user' object from login (only full_name, email, role),
                    // We might need to fetch profile first.

                    const profileRes = await api.get('/api/profile/api/profile/profile/me');
                    setProfile(profileRes.data);
                    const { zip_code, profession, city } = profileRes.data;

                    const eventsRes = await api.get(`/ai/recommend/events?zip_code=${zip_code || ''}`);
                    // Mock event location overwrite for demo
                    const cityEvents = eventsRes.data.map((e: any) => ({ ...e, location: city || 'Your City', title: `${e.title} in ${city || 'Town'}` }));
                    setEvents(cityEvents);

                    const interestsRes = await api.get(`/ai/recommend/interests?profession=${profession || ''}`);
                    setInterests(interestsRes.data);

                } catch (error) {
                    console.error("Failed to load recommendations", error);
                } finally {
                    setLoading(false);
                }
            }
        };

        fetchRecommendations();
    }, [isAuthenticated, user]);

    if (!isAuthenticated) {
        return (
            <div style={{ padding: '4rem 2rem', textAlign: 'center' }}>
                <h1 style={{ fontSize: '3rem', marginBottom: '1rem' }}>Welcome to Diaspora Platform</h1>
                <p style={{ fontSize: '1.2rem', marginBottom: '2rem', color: 'var(--color-text-muted)' }}>
                    Connect, Share, and Grow with your global community.
                </p>
                <div style={{ display: 'flex', gap: '1rem', justifyContent: 'center' }}>
                    <Link to="/register" style={{ padding: '0.75rem 1.5rem', background: 'var(--color-primary)', borderRadius: '0.5rem', fontWeight: 'bold' }}>
                        Join Now
                    </Link>
                    <Link to="/login" style={{ padding: '0.75rem 1.5rem', border: '1px solid var(--color-primary)', borderRadius: '0.5rem', fontWeight: 'bold' }}>
                        Login
                    </Link>
                </div>
            </div>
        );
    }

    return (
        <div style={{ padding: '2rem', maxWidth: '1200px', margin: '0 auto' }}>
            <div style={{ marginBottom: '3rem' }}>
                <h1 style={{ fontSize: '2rem', marginBottom: '0.5rem' }}>Welcome back, {user?.fullName || 'Member'}!</h1>
                <p style={{ fontSize: '1.2rem', color: 'var(--color-text-muted)' }}>
                    {profile?.profession ? `${profile.profession}` : 'Professional'} in <span style={{ color: 'var(--color-primary)' }}>{profile?.city || 'City'}, {profile?.country || 'Country'}</span>
                </p>
                <p style={{ marginTop: '0.5rem', color: 'var(--color-text-muted)' }}>Here is what's happening around you.</p>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '2rem' }}>
                {/* Events Section */}
                <div style={{ background: 'var(--color-bg-card)', padding: '1.5rem', borderRadius: '1rem' }}>
                    <h2 style={{ borderBottom: '1px solid #334155', paddingBottom: '0.5rem', marginBottom: '1rem' }}>
                        Events Near You
                    </h2>
                    {loading ? <p>Loading suggestions...</p> : (
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                            {events.map(event => (
                                <div key={event.id} style={{ padding: '1rem', background: 'rgba(255,255,255,0.05)', borderRadius: '0.5rem' }}>
                                    <h3 style={{ fontSize: '1.1rem', marginBottom: '0.25rem' }}>{event.title}</h3>
                                    <p style={{ fontSize: '0.9rem', color: 'var(--color-text-muted)' }}>{event.date} • {event.location}</p>
                                </div>
                            ))}
                            {events.length === 0 && <p>No events found for your location.</p>}
                        </div>
                    )}
                </div>

                {/* Interests Section */}
                <div style={{ background: 'var(--color-bg-card)', padding: '1.5rem', borderRadius: '1rem' }}>
                    <h2 style={{ borderBottom: '1px solid #334155', paddingBottom: '0.5rem', marginBottom: '1rem' }}>
                        Recommended for Your Profession
                    </h2>
                    {loading ? <p>Loading suggestions...</p> : (
                        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem' }}>
                            {interests.map(interest => (
                                <span key={interest.id} style={{
                                    padding: '0.5rem 1rem',
                                    background: 'var(--color-primary)',
                                    borderRadius: '2rem',
                                    fontSize: '0.9rem',
                                    display: 'inline-block'
                                }}>
                                    {interest.name}
                                </span>
                            ))}
                            {interests.length === 0 && <p>Update your profession to see recommendations.</p>}
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
};

export default Home;
