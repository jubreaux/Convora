import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { ArrowLeft, Loader, Edit2, Trash2 } from 'lucide-react';
import api from '../../services/api';
import { UserStats, SessionDetail, User } from '../../types';
import { toast } from 'react-toastify';
import { UserEditModal } from '../../components/UserEditModal';
import { UserDeleteConfirm } from '../../components/UserDeleteConfirm';

const UserDetail: React.FC = () => {
  const { userId } = useParams<{ userId: string }>();
  const navigate = useNavigate();
  const [user, setUser] = useState<UserStats | null>(null);
  const [sessions, setSessions] = useState<SessionDetail[]>([]);
  const [loading, setLoading] = useState(true);
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [showEditModal, setShowEditModal] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);

  // Get current user info on mount
  useEffect(() => {
    api.getCurrentUser().then(setCurrentUser).catch(console.error);
  }, []);

  useEffect(() => {
    const fetchData = async () => {
      if (!userId) return;

      setLoading(true);
      try {
        const userNum = parseInt(userId, 10);
        const userDetail = await api.getUserDetail(userNum);
        setUser(userDetail);
        
        // Try to fetch sessions - this may not exist depending on backend
        try {
          const userSessions = await api.getUserSessions(userNum);
          setSessions(userSessions);
        } catch (err) {
          console.log('Could not fetch session history');
        }
      } catch (err: any) {
        toast.error('Failed to fetch user details');
        console.error(err);
        navigate('/users');
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [userId, navigate]);

  const handleEditSuccess = (updatedUser: User) => {
    setShowEditModal(false);
    toast.success('User updated successfully');
    // Update the displayed user info
    setUser((prevUser) => prevUser ? { ...prevUser, ...updatedUser } : null);
  };

  const handleDeleteSuccess = () => {
    setShowDeleteConfirm(false);
    toast.success('User deleted successfully');
    // Navigate back to user list
    navigate('/users');
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader className="animate-spin text-blue-600" size={24} />
      </div>
    );
  }

  if (!user) {
    return (
      <div className="text-center py-12">
        <p className="text-gray-600">User not found</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Back Button */}
      <button
        onClick={() => navigate('/users')}
        className="flex items-center space-x-2 text-blue-600 hover:text-blue-700 transition"
      >
        <ArrowLeft size={20} />
        <span>Back to Users</span>
      </button>

      {/* User Info Header */}
      <div className="bg-white rounded-lg shadow p-6">
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">{user.name}</h1>
            <p className="text-gray-500 mt-1">{user.email}</p>
          </div>
          <div className="flex items-start gap-4">
            <div className="text-right">
              <p className="text-sm text-gray-500">Joined</p>
              <p className="text-lg font-semibold text-gray-900">
                {new Date(user.created_at).toLocaleDateString()}
              </p>
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={() => setShowEditModal(true)}
                disabled={user.id === currentUser?.id}
                className="p-2 text-blue-600 hover:bg-blue-50 rounded disabled:opacity-50 disabled:cursor-not-allowed transition"
                title={user.id === currentUser?.id ? 'Cannot edit yourself' : 'Edit user'}
              >
                <Edit2 size={20} />
              </button>
              <button
                onClick={() => setShowDeleteConfirm(true)}
                disabled={user.id === currentUser?.id}
                className="p-2 text-red-600 hover:bg-red-50 rounded disabled:opacity-50 disabled:cursor-not-allowed transition"
                title={user.id === currentUser?.id ? 'Cannot delete yourself' : 'Delete user'}
              >
                <Trash2 size={20} />
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white rounded-lg shadow p-6">
          <p className="text-sm text-gray-500">Total Sessions</p>
          <p className="text-3xl font-bold text-gray-900 mt-2">{user.total_sessions}</p>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <p className="text-sm text-gray-500">Total Score</p>
          <p className="text-3xl font-bold text-gray-900 mt-2">{user.total_score}</p>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <p className="text-sm text-gray-500">Average Score</p>
          <p className="text-3xl font-bold text-gray-900 mt-2">
            {user.avg_session_score.toFixed(1)}
          </p>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <p className="text-sm text-gray-500">Objectives Completed</p>
          <p className="text-3xl font-bold text-gray-900 mt-2">{user.completed_objectives}</p>
        </div>
      </div>

      {/* Last Session */}
      {user.last_session_date && (
        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-4">Last Session</h2>
          <p className="text-gray-600">
            {new Date(user.last_session_date).toLocaleString()}
          </p>
        </div>
      )}

      {/* Session History */}
      {sessions.length > 0 && (
        <div className="bg-white rounded-lg shadow overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-200">
            <h2 className="text-xl font-semibold text-gray-900">Session History</h2>
          </div>
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">ID</th>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Status</th>
                <th className="px-6 py-3 text-right text-sm font-semibold text-gray-900">Score</th>
                <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Date</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {sessions.map((session) => (
                <tr
                  key={session.id}
                  className="hover:bg-gray-50 cursor-pointer"
                  onClick={() => navigate(`/sessions/${session.id}`)}
                >
                  <td className="px-6 py-4 text-sm text-gray-900">#{session.id}</td>
                  <td className="px-6 py-4 text-sm">
                    <span className={`inline-block px-3 py-1 rounded-full text-xs font-semibold ${
                      session.status === 'completed'
                        ? 'bg-green-100 text-green-800'
                        : session.status === 'abandoned'
                        ? 'bg-red-100 text-red-800'
                        : 'bg-blue-100 text-blue-800'
                    }`}>
                      {session.status}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-sm text-gray-900 text-right font-semibold">{session.score}</td>
                  <td className="px-6 py-4 text-sm text-gray-500">
                    {new Date(session.started_at).toLocaleDateString()}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Edit Modal */}
      {user && currentUser && (
        <UserEditModal
          user={user}
          isOpen={showEditModal}
          onClose={() => setShowEditModal(false)}
          onSuccess={handleEditSuccess}
          currentUserId={currentUser.id}
        />
      )}

      {/* Delete Confirmation */}
      {user && (
        <UserDeleteConfirm
          userId={user.id}
          userEmail={user.email}
          isOpen={showDeleteConfirm}
          onClose={() => setShowDeleteConfirm(false)}
          onSuccess={handleDeleteSuccess}
        />
      )}
    </div>
  );
};

export default UserDetail;
