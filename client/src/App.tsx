import { BrowserRouter, Routes, Route, Link, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import Login from './pages/Login';
import Register from './pages/Register';
import Profile from './pages/Profile';
import Home from './pages/Home';
import './styles/index.css';

// Protected Route Component
const ProtectedRoute = ({ children }: { children: JSX.Element }) => {
    const { isAuthenticated, isLoading } = useAuth();

    if (isLoading) return <div>Loading...</div>;
    if (!isAuthenticated) return <Navigate to="/api/auth/login" />;

    return children;
};

// Navigation Component
const Navigation = () => {
    const { isAuthenticated, logout } = useAuth();
    return (
        <header className="main-header">
            <div className="logo">Diaspora Platform</div>
            <nav>
                <Link to="/">Home</Link>
                {isAuthenticated ? (
                    <>
                        <Link to="/profile">Profile</Link>
                        <a href="#" onClick={(e) => { e.preventDefault(); logout(); }}>Logout</a>
                    </>
                ) : (
                    <>
                        <Link to="/api/auth/login">Login</Link>
                        <Link to="/api/auth/api/auth/auth/api/auth/auth/register">Register</Link>
                    </>
                )}
            </nav>
        </header>
    );
};



// Profile Placeholder (until we build the full one)


function App() {
    return (
        <AuthProvider>
            <BrowserRouter>
                <div className="app-container">
                    <Navigation />
                    <Routes>
                        <Route path="/" element={<Home />} />
                        <Route path="/api/auth/login" element={<Login />} />
                        <Route path="/api/auth/api/auth/auth/api/auth/auth/register" element={<Register />} />
                        <Route path="/profile" element={
                            <ProtectedRoute>
                                <Profile />
                            </ProtectedRoute>
                        } />
                    </Routes>
                </div>
            </BrowserRouter>
        </AuthProvider>
    );
}

export default App;
