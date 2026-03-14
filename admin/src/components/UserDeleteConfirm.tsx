import React, { useState } from 'react';
import api from '../services/api';

interface UserDeleteConfirmProps {
  userId: number;
  userEmail: string;
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
}

export const UserDeleteConfirm: React.FC<UserDeleteConfirmProps> = ({
  userId,
  userEmail,
  isOpen,
  onClose,
  onSuccess,
}) => {
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string>('');

  const handleConfirmDelete = async () => {
    setError('');
    setIsLoading(true);

    try {
      await api.deleteUser(userId);
      onSuccess();
      onClose();
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Failed to delete user');
    } finally {
      setIsLoading(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg shadow-lg max-w-md w-full mx-4">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">Delete User</h2>
        </div>

        <div className="p-6 space-y-4">
          {error && (
            <div className="p-3 bg-red-50 border border-red-200 rounded-md text-red-700 text-sm">
              {error}
            </div>
          )}

          <div className="bg-yellow-50 border border-yellow-200 rounded-md p-4">
            <p className="text-sm text-yellow-800">
              <strong>Warning:</strong> You are about to delete the user{' '}
              <strong>{userEmail}</strong>. This action cannot be undone.
            </p>
          </div>

          <p className="text-sm text-gray-600">
            The user's data will be preserved in the system but will not be visible in the admin panel.
          </p>

          <div className="flex gap-3 pt-4">
            <button
              onClick={onClose}
              disabled={isLoading}
              className="flex-1 px-4 py-2 border border-gray-300 rounded-md text-gray-700 font-medium hover:bg-gray-50 disabled:opacity-50"
            >
              Cancel
            </button>
            <button
              onClick={handleConfirmDelete}
              disabled={isLoading}
              className="flex-1 px-4 py-2 bg-red-600 text-white rounded-md font-medium hover:bg-red-700 disabled:opacity-50"
            >
              {isLoading ? 'Deleting...' : 'Delete User'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
