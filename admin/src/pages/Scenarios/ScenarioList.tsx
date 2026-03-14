import React, { useState, useEffect } from 'react';
import { Trash2, Plus, Loader, Pencil } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import api from '../../services/api';
import { Scenario } from '../../types';
import { toast } from 'react-toastify';
import CreateScenarioModal from '../../components/CreateScenarioModal';

const ScenarioList: React.FC = () => {
  const navigate = useNavigate();
  const [scenarios, setScenarios] = useState<Scenario[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [deleting, setDeleting] = useState<number | null>(null);

  const fetchScenarios = async () => {
    setLoading(true);
    try {
      const data = await api.listScenarios();
      setScenarios(data);
    } catch (err: any) {
      toast.error('Failed to fetch scenarios');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchScenarios();
  }, []);

  const handleDelete = async (scenarioId: number) => {
    // eslint-disable-next-line no-restricted-globals
    if (!confirm('Are you sure you want to delete this scenario? This action cannot be undone.')) {
      return;
    }

    setDeleting(scenarioId);
    try {
      await api.deleteScenario(scenarioId);
      setScenarios(scenarios.filter(s => s.id !== scenarioId));
      toast.success('Scenario deleted successfully');
    } catch (err: any) {
      toast.error('Failed to delete scenario');
      console.error(err);
    } finally {
      setDeleting(null);
    }
  };

  const handleScenarioCreated = () => {
    setShowCreateModal(false);
    fetchScenarios();
  };

  const getDiscColor = (discType: string) => {
    const colors: { [key: string]: string } = {
      D: 'bg-red-100 text-red-800',
      I: 'bg-yellow-100 text-yellow-800',
      S: 'bg-green-100 text-green-800',
      C: 'bg-blue-100 text-blue-800',
    };
    return colors[discType] || 'bg-gray-100 text-gray-800';
  };

  const getDiscLabel = (discType: string) => {
    const labels: { [key: string]: string } = {
      D: 'Direct',
      I: 'Influential',
      S: 'Steady',
      C: 'Conscientious',
    };
    return labels[discType] || discType;
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold text-gray-900">Scenarios</h1>
        <button
          onClick={() => setShowCreateModal(true)}
          className="flex items-center space-x-2 bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-lg transition"
        >
          <Plus size={20} />
          <span>New Scenario</span>
        </button>
      </div>

      {/* Create Modal */}
      {showCreateModal && (
        <CreateScenarioModal
          onClose={() => setShowCreateModal(false)}
          onSuccess={handleScenarioCreated}
        />
      )}

      {/* Scenarios Table */}
      <div className="bg-white rounded-lg shadow overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center h-64">
            <Loader className="animate-spin text-blue-600" size={24} />
          </div>
        ) : scenarios.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-64">
            <p className="text-gray-500 mb-4">No scenarios found</p>
            <button
              onClick={() => setShowCreateModal(true)}
              className="text-blue-600 hover:text-blue-700 font-medium"
            >
              Create your first scenario
            </button>
          </div>
        ) : (
          <>
            <table className="w-full">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Title</th>
                  <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">DISC Type</th>
                  <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Visibility</th>
                  <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Created</th>
                  <th className="px-6 py-3 text-right text-sm font-semibold text-gray-900">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {scenarios.map((scenario) => (
                  <tr key={scenario.id} className="hover:bg-gray-50 transition cursor-pointer" onClick={() => navigate(`/scenarios/${scenario.id}`)}>
                    <td className="px-6 py-4">
                      <div>
                        <p className="text-sm font-medium text-gray-900">{scenario.title}</p>
                        {scenario.ai_system_prompt && (
                          <p className="text-xs text-gray-500 mt-1 line-clamp-2">
                            {scenario.ai_system_prompt.substring(0, 100)}...
                          </p>
                        )}
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <span className={`inline-block px-3 py-1 rounded-full text-xs font-semibold ${getDiscColor(scenario.disc_type)}`}>
                        {getDiscLabel(scenario.disc_type)}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-sm">
                      <span className={`inline-block px-3 py-1 rounded-full text-xs font-semibold ${
                        scenario.is_public
                          ? 'bg-green-100 text-green-800'
                          : 'bg-gray-100 text-gray-800'
                      }`}>
                        {scenario.is_public ? 'Public' : 'Private'}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-500">
                      {scenario.created_at ? new Date(scenario.created_at).toLocaleDateString() : 'N/A'}
                    </td>
                    <td className="px-6 py-4 text-right">
                      <div className="flex items-center justify-end space-x-2">
                        <button
                          onClick={(e) => { e.stopPropagation(); navigate(`/scenarios/${scenario.id}`); }}
                          className="text-blue-500 hover:text-blue-700 transition"
                          title="Edit scenario"
                        >
                          <Pencil size={18} />
                        </button>
                        <button
                          onClick={(e) => { e.stopPropagation(); handleDelete(scenario.id); }}
                          disabled={deleting === scenario.id}
                          className="text-red-600 hover:text-red-700 disabled:opacity-50 disabled:cursor-not-allowed transition"
                          title="Delete scenario"
                        >
                          <Trash2 size={18} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>

            {/* Footer */}
            <div className="bg-gray-50 border-t border-gray-200 px-6 py-4">
              <p className="text-sm text-gray-600">
                Total: {scenarios.length} scenario{scenarios.length !== 1 ? 's' : ''}
              </p>
            </div>
          </>
        )}
      </div>
    </div>
  );
};

export default ScenarioList;
