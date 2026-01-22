import { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import api from '../services/api';
import { LOCATION_DATA, COUNTRIES_LIST } from '../constants/locations';

const Profile = () => {
    const { user } = useAuth();
    const [isEditing, setIsEditing] = useState(false);
    const [loading, setLoading] = useState(true);
    const [profile, setProfile] = useState({
        bio: '',
        location: '', // Deprecated in UI but kept for compatibility
        zipCode: '',
        country: '',
        state: '',
        city: '',
        profession: '',
        interests: '',
        privacySettings: {}
    });

    // Derived lists for cascading dropdowns
    const statesList = profile.country && LOCATION_DATA[profile.country] ? Object.keys(LOCATION_DATA[profile.country]) : [];
    const citiesList = profile.country && profile.state && LOCATION_DATA[profile.country]?.[profile.state] ? LOCATION_DATA[profile.country][profile.state] : [];


    useEffect(() => {
        const fetchProfile = async () => {
            try {
                const response = await api.get('/api/profile/api/profile/profile/me');
                const data = response.data;
                setProfile({
                    bio: data.bio,
                    location: data.location,
                    zipCode: data.zip_code,
                    country: data.country,
                    state: data.state,
                    city: data.city,
                    profession: data.profession,
                    interests: data.interests,
                    privacySettings: data.privacy_settings || {}
                });
            } catch (error: any) {
                if (error.response?.status === 404) {
                    console.log('No profile found, ready to create one.');
                } else {
                    console.error('Error fetching profile:', error);
                }
            } finally {
                setLoading(false);
            }
        };

        fetchProfile();
    }, []);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        try {
            const response = await api.put('/api/profile/api/profile/profile/me', profile);
            const data = response.data;
            setProfile({
                bio: data.bio,
                location: data.location,
                zipCode: data.zip_code,
                country: data.country,
                state: data.state, // Ensure state is saved back
                city: data.city,
                profession: data.profession,
                interests: data.interests,
                privacySettings: data.privacy_settings || {}
            });
            setIsEditing(false);
        } catch (error) {
            console.error('Error updating profile:', error);
            alert('Failed to update profile');
        }
    };

    const handleCountryChange = (e: any) => {
        setProfile({ ...profile, country: e.target.value, state: '', city: '' });
    };

    const handleStateChange = (e: any) => {
        setProfile({ ...profile, state: e.target.value, city: '' });
    };

    if (loading) return <div style={{ padding: '2rem', textAlign: 'center' }}>Loading profile...</div>;

    return (
        <div style={{ maxWidth: '800px', margin: '2rem auto', padding: '0 1rem' }}>
            <div style={{ background: 'var(--color-bg-card)', borderRadius: '1rem', padding: '2rem', boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)' }}>
                <div style={{ marginBottom: '2rem', borderBottom: '1px solid #334155', paddingBottom: '2rem' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                        <div>
                            <h1 style={{ marginBottom: '0.5rem', fontSize: '2.5rem' }}>{user?.fullName}</h1>
                            <p style={{ fontSize: '1.2rem', color: 'var(--color-primary)', marginBottom: '0.5rem' }}>{profile.profession || 'Profession Not Set'}</p>
                            <p style={{ color: 'var(--color-text-muted)' }}>
                                {profile.city}, {profile.state ? `${profile.state}, ` : ''}{profile.country}
                                {profile.zipCode && ` • ${profile.zipCode}`}
                            </p>
                        </div>
                        <button
                            onClick={() => setIsEditing(!isEditing)}
                            style={{ background: isEditing ? 'transparent' : 'var(--color-primary)', border: isEditing ? '1px solid var(--color-primary)' : 'none', padding: '0.5rem 1.5rem', borderRadius: '0.5rem', cursor: 'pointer' }}
                        >
                            {isEditing ? 'Cancel' : 'Edit Profile'}
                        </button>
                    </div>
                </div>

                {isEditing ? (
                    <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
                        <div>
                            <label style={{ display: 'block', marginBottom: '0.5rem' }}>Profession / Title</label>
                            <input
                                type="text"
                                value={profile.profession || ''}
                                onChange={e => setProfile({ ...profile, profession: e.target.value })}
                                placeholder="e.g. Software Engineer"
                                style={{ width: '100%', padding: '0.75rem', borderRadius: '0.5rem', background: '#1e293b', border: '1px solid #334155', color: 'white' }}
                            />
                        </div>
                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                            <div>
                                <label style={{ display: 'block', marginBottom: '0.5rem' }}>Country</label>
                                <input
                                    list="country-list"
                                    type="text"
                                    value={profile.country || ''}
                                    onChange={handleCountryChange}
                                    placeholder="Search Country"
                                    style={{ width: '100%', padding: '0.75rem', borderRadius: '0.5rem', background: '#1e293b', border: '1px solid #334155', color: 'white' }}
                                />
                                <datalist id="country-list">
                                    {COUNTRIES_LIST.map(c => (
                                        <option key={c} value={c} />
                                    ))}
                                </datalist>
                            </div>
                            <div>
                                <label style={{ display: 'block', marginBottom: '0.5rem' }}>State / Region</label>
                                <input
                                    list="state-list"
                                    type="text"
                                    value={profile.state || ''}
                                    onChange={handleStateChange}
                                    placeholder={statesList.length ? "Select State" : "Enter State"}
                                    style={{ width: '100%', padding: '0.75rem', borderRadius: '0.5rem', background: '#1e293b', border: '1px solid #334155', color: 'white' }}
                                />
                                <datalist id="state-list">
                                    {statesList.map(s => (
                                        <option key={s} value={s} />
                                    ))}
                                </datalist>
                            </div>
                            <div>
                                <label style={{ display: 'block', marginBottom: '0.5rem' }}>City</label>
                                <input
                                    list="city-list"
                                    type="text"
                                    value={profile.city || ''}
                                    onChange={e => setProfile({ ...profile, city: e.target.value })}
                                    placeholder={citiesList.length ? "Select City" : "Enter City"}
                                    style={{ width: '100%', padding: '0.75rem', borderRadius: '0.5rem', background: '#1e293b', border: '1px solid #334155', color: 'white' }}
                                />
                                <datalist id="city-list">
                                    {citiesList.map(c => (
                                        <option key={c} value={c} />
                                    ))}
                                </datalist>
                            </div>
                        </div>
                        <div>
                            <label style={{ display: 'block', marginBottom: '0.5rem' }}>Zipcode / Postal Code</label>
                            <input
                                type="text"
                                value={profile.zipCode || ''}
                                onChange={e => setProfile({ ...profile, zipCode: e.target.value })}
                                placeholder="e.g. 10001"
                                style={{ width: '100%', padding: '0.75rem', borderRadius: '0.5rem', background: '#1e293b', border: '1px solid #334155', color: 'white' }}
                            />
                        </div>

                        {/* Hidden legacy location field update */}
                        <input type="hidden" value={profile.location} />

                        <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: '1rem' }}>
                            <button type="submit">Save Changes</button>
                        </div>
                    </form>
                ) : (
                    <div style={{ display: 'grid', gap: '1.5rem' }}>
                        {/* Profession and Location moved to header */}
                        <div>
                            <h3 style={{ fontSize: '0.875rem', color: 'var(--color-text-muted)', marginBottom: '0.25rem' }}>BIO</h3>
                            <p style={{ lineHeight: '1.6' }}>{profile.bio || 'No bio yet.'}</p>
                        </div>
                        <div>
                            <h3 style={{ fontSize: '0.875rem', color: 'var(--color-text-muted)', marginBottom: '0.25rem' }}>INTERESTS</h3>
                            <p>{profile.interests || 'Not specified'}</p>
                        </div>
                    </div>
                )}
            </div>
        </div >
    );
};

export default Profile;
