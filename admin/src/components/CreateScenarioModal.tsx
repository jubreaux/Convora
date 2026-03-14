import React, { useState } from 'react';
import { X, Loader } from 'lucide-react';
import api from '../services/api';
import { toast } from 'react-toastify';

interface CreateScenarioModalProps {
  onClose: () => void;
  onSuccess: () => void;
}

const CreateScenarioModal: React.FC<CreateScenarioModalProps> = ({ onClose, onSuccess }) => {
  const [title, setTitle] = useState('');
  const [discType, setDiscType] = useState<'D' | 'I' | 'S' | 'C'>('D');
  const [visibility, setVisibility] = useState<'personal' | 'org' | 'default' | 'public'>('personal');
  const [systemPrompt, setSystemPrompt] = useState('');
  const [loading, setLoading] = useState(false);
  const [errors, setErrors] = useState<{ [key: string]: string }>({});

  const validateForm = () => {
    const newErrors: { [key: string]: string } = {};

    if (!title.trim()) {
      newErrors.title = 'Title is required';
    }

    if (!systemPrompt.trim()) {
      newErrors.systemPrompt = 'System prompt is required';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!validateForm()) {
      return;
    }

    setLoading(true);
    try {
      await api.createScenario({
        title: title.trim(),
        disc_type: discType,
        visibility: visibility,
        ai_system_prompt: systemPrompt.trim(),
      });

      toast.success('Scenario created successfully');
      onSuccess();
    } catch (err: any) {
      const errorMsg = err.response?.data?.detail || 'Failed to create scenario';
      toast.error(typeof errorMsg === 'string' ? errorMsg : 'Failed to create scenario');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg shadow-lg max-w-2xl w-full">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-200">
          <h2 className="text-xl font-semibold text-gray-900">Create New Scenario</h2>
          <button
            onClick={onClose}
            disabled={loading}
            className="text-gray-400 hover:text-gray-600 disabled:opacity-50"
          >
            <X size={24} />
          </button>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          {/* Title */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Title *
            </label>
            <input
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="e.g., Open House Conversation"
              className={`w-full px-4 py-2 border rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition ${
                errors.title ? 'border-red-500' : 'border-gray-300'
              }`}
            />
            {errors.title && (
              <p className="text-red-500 text-xs mt-1">{errors.title}</p>
            )}
          </div>

          {/* DISC Type */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                DISC Type *
              </label>
              <select
                value={discType}
                onChange={(e) => setDiscType(e.target.value as 'D' | 'I' | 'S' | 'C')}
                className="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition"
              >
                <option value="D">D - Direct</option>
                <option value="I">I - Influential</option>
                <option value="S">S - Steady</option>
                <option value="C">C - Conscientious</option>
              </select>
            </div>

            {/* Visibility Selector */}
            <div className="flex flex-col justify-between">
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Visibility
              </label>
              <select
                value={visibility}
                onChange={(e) => setVisibility(e.target.value as 'personal' | 'org' | 'default' | 'public')}
                className="w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition"
              >
                <option value="personal">Personal (Only me)</option>
                <option value="org">Organization (Org members)</option>
                <option value="default">Default (Platform provided)</option>
                <option value="public">Public (Everyone)</option>
              </select>
            </div>
          </div>

          {/* System Prompt */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              AI System Prompt *
            </label>
            <textarea
              value={systemPrompt}
              onChange={(e) => setSystemPrompt(e.target.value)}
              placeholder="Enter the system prompt that will guide the AI's behavior in this scenario..."
              rows={6}
              className={`w-full px-4 py-2 border rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition resize-none ${
                errors.systemPrompt ? 'border-red-500' : 'border-gray-300'
              }`}
            />
            {errors.systemPrompt && (
              <p className="text-red-500 text-xs mt-1">{errors.systemPrompt}</p>
            )}
            <p className="text-xs text-gray-500 mt-1">
              {systemPrompt.length} characters
            </p>
          </div>

          {/* Actions */}
          <div className="flex justify-end space-x-3 pt-4">
            <button
              type="button"
              onClick={onClose}
              disabled={loading}
              className="px-4 py-2 text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-md transition disabled:opacity-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={loading}
              className="flex items-center space-x-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400 text-white rounded-md transition"
            >
              {loading && <Loader className="animate-spin" size={16} />}
              <span>{loading ? 'Creating...' : 'Create Scenario'}</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default CreateScenarioModal;
