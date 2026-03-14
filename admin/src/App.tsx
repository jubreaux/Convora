import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { ToastContainer } from 'react-toastify';
import 'react-toastify/dist/ReactToastify.css';

import api from './services/api';
import { User } from './types';
import Layout from './components/Layout';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import UserList from './pages/Users/UserList';
import UserDetail from './pages/Users/UserDetail';
import ScenarioList from './pages/Scenarios/ScenarioList';
import ScenarioDetail from './pages/Scenarios/ScenarioDetail';
import SessionDetail from './pages/Sessions/SessionDetail';

const ProtectedRoute: React.FC<{
  children: React.ReactNode;
  user: User | null;
  isLoading: boolean;
}> = ({ children, user, isLoading }) => {
  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-screen">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Loading...</p>
        </div>
      </div>
    );
  }

  if (!user || user.role !== 'admin') {
    return <Navigate to="/login" replace />;
  }

  return <Layout user={user}>{children}</Layout>;
};

const App: React.FC = () => {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const initAuth = async () => {
      const token = api.getToken();
      if (token) {
        try {
          const response = await api.healthCheck();
          if (response) {
            setUser({
              id: 1,
              email: 'admin@example.com',
              name: 'Admin User',
              role: 'admin',
              created_at: new Date().toISOString(),
            });
          }
        } catch (err) {
          api.clearToken();
          setUser(null);
        }
      }
      setIsLoading(false);
    };

    initAuth();
  }, []);

  return (
    <Router>
      <ToastContainer
        position="top-right"
        autoClose={3000}
        hideProgressBar={false}
        newestOnTop={true}
        closeOnClick
        rtl={false}
        pauseOnFocusLoss
        draggable
        pauseOnHover
      />
      
      <Routes>
        <Route path="/login" element={<Login />} />
        
        <Route
          path="/dashboard"
          element={
            <ProtectedRoute user={user} isLoading={isLoading}>
              <Dashboard />
            </ProtectedRoute>
          }
        />

        <Route
          path="/users"
          element={
            <ProtectedRoute user={user} isLoading={isLoading}>
              <UserList />
            </ProtectedRoute>
          }
        />

        <Route
          path="/users/:userId"
          element={
            <ProtectedRoute user={user} isLoading={isLoading}>
              <UserDetail />
            </ProtectedRoute>
          }
        />

        <Route
          path="/scenarios"
          element={
            <ProtectedRoute user={user} isLoading={isLoading}>
              <ScenarioList />
            </ProtectedRoute>
          }
        />

        <Route
          path="/scenarios/:scenarioId"
          element={
            <ProtectedRoute user={user} isLoading={isLoading}>
              <ScenarioDetail />
            </ProtectedRoute>
          }
        />

        <Route
          path="/sessions/:sessionId"
          element={
            <ProtectedRoute user={user} isLoading={isLoading}>
              <SessionDetail />
            </ProtectedRoute>
          }
        />

        <Route path="/" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </Router>
  );
};

export default App;
