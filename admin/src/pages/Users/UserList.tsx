import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search, ChevronLeft, ChevronRight, Loader, Edit2, Trash2, Plus } from 'lucide-react';
import api from '../../services/api';
import { UserStats, User } from '../../types';
import { toast } from 'react-toastify';
import { UserEditModal } from '../../components/UserEditModal';
import { UserDeleteConfirm } from '../../components/UserDeleteConfirm';
import { UserCreateModal } from '../../components/UserCreateModal';

const UserList: React.FC = () => {
  const navigate = useNavigate();
  const [users, setUsers] = useState<UserStats[]>([]);
  const [search, setSearch] = useState('');
  const [offset, setOffset] = useState(0);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [editingUser, setEditingUser] = useState<UserStats | null>(null);
  const [deletingUser, setDeletingUser] = useState<UserStats | null>(null);
  const [showEditModal, setShowEditModal] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const limit = 20;

  // Get current user info on mount
  useEffect(() => {
    api.getCurrentUser().then(setCurrentUser).catch(console.error);
  }, []);

  const fetchUsers = useCallback(async (searchTerm = '', page = 0) => {
    setLoading(true);
    try {
      const result = await api.getUsers({
        search: searchTerm,
        offset: page,
        limit,
      });
      setUsers(result.users);
      setTotal(result.total);
      setOffset(page);
    } catch (err: any) {
      toast.error('Failed to fetch users');
      console.error(err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchUsers('', 0);
  }, [fetchUsers]);

  const handleSearch = (e: React.ChangeEvent<HTMLInputElement>) => {
    setSearch(e.target.value);
    // Debounce search
    const timer = setTimeout(() => {
      fetchUsers(e.target.value, 0);
    }, 300);
    return () => clearTimeout(timer);
  };

  const handlePrevPage = () => {
    const newOffset = Math.max(0, offset - limit);
    fetchUsers(search, newOffset);
  };

  const handleNextPage = () => {
    if (offset + limit < total) {
      fetchUsers(search, offset + limit);
    }
  };

  const handleEditClick = (e: React.MouseEvent, user: UserStats) => {
    e.stopPropagation();
    setEditingUser(user);
    setShowEditModal(true);
  };

  const handleDeleteClick = (e: React.MouseEvent, user: UserStats) => {
    e.stopPropagation();
    setDeletingUser(user);
    setShowDeleteConfirm(true);
  };

  const handleEditSuccess = (updatedUser: User) => {
    setShowEditModal(false);
    toast.success('User updated successfully');
    fetchUsers(search, offset);
  };

  const handleDeleteSuccess = () => {
    setShowDeleteConfirm(false);
    toast.success('User deleted successfully');
    fetchUsers(search, offset);
  };

  const handleCreateSuccess = () => {
    setShowCreateModal(false);
    toast.success('User created successfully');
    fetchUsers(search, 0);  // Refresh list and go back to page 1
  };

  const currentPage = Math.floor(offset / limit) + 1;
  const totalPages = Math.ceil(total / limit);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold text-gray-900">Users</h1>
        <button
          onClick={() => setShowCreateModal(true)}
          className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition"
        >
          <Plus size={20} />
          Create User
        </button>
      </div>

      {/* Search Bar */}
      <div className="bg-white rounded-lg shadow p-4">
        <div className="relative">
          <Search className="absolute left-3 top-3 text-gray-400" size={20} />
          <input
            type="text"
            placeholder="Search by email or name..."
            value={search}
            onChange={handleSearch}
            className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none"
          />
        </div>
      </div>

      {/* Users Table */}
      <div className="bg-white rounded-lg shadow overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center h-64">
            <Loader className="animate-spin text-blue-600" size={24} />
          </div>
        ) : users.length === 0 ? (
          <div className="flex items-center justify-center h-64">
            <p className="text-gray-500">No users found</p>
          </div>
        ) : (
          <>
            <table className="w-full">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Email</th>
                  <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Name</th>
                  <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Account Type</th>
                  <th className="px-6 py-3 text-right text-sm font-semibold text-gray-900">Sessions</th>
                  <th className="px-6 py-3 text-right text-sm font-semibold text-gray-900">Score</th>
                  <th className="px-6 py-3 text-right text-sm font-semibold text-gray-900">Avg Score</th>
                  <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Joined</th>
                  <th className="px-6 py-3 text-center text-sm font-semibold text-gray-900">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {users.map((user) => (
                  <tr
                    key={user.id}
                    onClick={() => navigate(`/users/${user.id}`)}
                    className="hover:bg-gray-50 cursor-pointer transition"
                  >
                    <td className="px-6 py-4 text-sm text-gray-900">{user.email}</td>
                    <td className="px-6 py-4 text-sm text-gray-700">{user.name}</td>
                    <td className="px-6 py-4 text-sm">
                      {user.org_role ? (
                        <span className={`inline-block px-3 py-1 rounded-full text-xs font-semibold ${
                          user.org_role === 'org_admin' 
                            ? 'bg-purple-100 text-purple-800' 
                            : 'bg-blue-100 text-blue-800'
                        }`}>
                          {user.org_role === 'org_admin' ? '🏢 Corp Admin' : '👤 Corp Employee'}
                        </span>
                      ) : (
                        <span className="inline-block px-3 py-1 rounded-full text-xs font-semibold bg-gray-100 text-gray-700">
                          Personal
                        </span>
                      )}
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-700 text-right">{user.total_sessions}</td>
                    <td className="px-6 py-4 text-sm text-gray-700 text-right font-semibold">{user.total_score}</td>
                    <td className="px-6 py-4 text-sm text-gray-700 text-right">{user.avg_session_score.toFixed(1)}</td>
                    <td className="px-6 py-4 text-sm text-gray-500">
                      {new Date(user.created_at).toLocaleDateString()}
                    </td>
                    <td className="px-6 py-4 text-center">
                      <div className="flex items-center justify-center gap-2">
                        <button
                          onClick={(e) => handleEditClick(e, user)}
                          disabled={user.id === currentUser?.id}
                          className="p-2 text-blue-600 hover:bg-blue-50 rounded disabled:opacity-50 disabled:cursor-not-allowed transition"
                          title={user.id === currentUser?.id ? 'Cannot edit yourself' : 'Edit user'}
                        >
                          <Edit2 size={16} />
                        </button>
                        <button
                          onClick={(e) => handleDeleteClick(e, user)}
                          disabled={user.id === currentUser?.id}
                          className="p-2 text-red-600 hover:bg-red-50 rounded disabled:opacity-50 disabled:cursor-not-allowed transition"
                          title={user.id === currentUser?.id ? 'Cannot delete yourself' : 'Delete user'}
                        >
                          <Trash2 size={16} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>

            {/* Pagination */}
            <div className="bg-gray-50 border-t border-gray-200 px-6 py-4 flex items-center justify-between">
              <div className="text-sm text-gray-600">
                Showing {offset + 1} to {Math.min(offset + limit, total)} of {total} users
              </div>
              <div className="flex items-center space-x-2">
                <button
                  onClick={handlePrevPage}
                  disabled={offset === 0}
                  className="p-2 hover:bg-gray-200 rounded disabled:opacity-50 disabled:cursor-not-allowed transition"
                >
                  <ChevronLeft size={20} />
                </button>
                <span className="text-sm text-gray-700">
                  Page {currentPage} of {totalPages}
                </span>
                <button
                  onClick={handleNextPage}
                  disabled={offset + limit >= total}
                  className="p-2 hover:bg-gray-200 rounded disabled:opacity-50 disabled:cursor-not-allowed transition"
                >
                  <ChevronRight size={20} />
                </button>
              </div>
            </div>
          </>
        )}
      </div>

      {/* Edit Modal */}
      {editingUser && currentUser && (
        <UserEditModal
          user={editingUser}
          isOpen={showEditModal}
          onClose={() => {
            setShowEditModal(false);
            setEditingUser(null);
          }}
          onSuccess={handleEditSuccess}
          currentUserId={currentUser.id}
        />
      )}

      {/* Delete Confirmation */}
      {deletingUser && (
        <UserDeleteConfirm
          userId={deletingUser.id}
          userEmail={deletingUser.email}
          isOpen={showDeleteConfirm}
          onClose={() => {
            setShowDeleteConfirm(false);
            setDeletingUser(null);
          }}
          onSuccess={handleDeleteSuccess}
        />
      )}

      {/* Create User Modal */}
      <UserCreateModal
        isOpen={showCreateModal}
        onClose={() => setShowCreateModal(false)}
        onSuccess={handleCreateSuccess}
      />
    </div>
  );
};

export default UserList;
