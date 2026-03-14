import React, { useState, useEffect, useCallback } from 'react';
import { Trash2, Plus, Loader, Pencil, Search, ChevronUp, ChevronDown } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import api from '../../services/api';
import { AdminScenario } from '../../types';
import { toast } from 'react-toastify';
import CreateScenarioModal from '../../components/CreateScenarioModal';

type SortBy = 'title' | 'created_at' | 'visibility' | 'disc_type';
type SortOrder = 'asc' | 'desc';
type VisibilityFilter = 'all' | 'personal' | 'org' | 'public';

const ScenarioList: React.FC = () => {
  const navigate = useNavigate();
  const [scenarios, setScenarios] = useState<AdminScenario[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [deleting, setDeleting] = useState<number | null>(null);

  // Filters and search
  const [search, setSearch] = useState('');
  const [visibility, setVisibility] = useState<VisibilityFilter>('all');
  const [sortBy, setSortBy] = useState<SortBy>('created_at');
  const [sortOrder, setSortOrder] = useState<SortOrder>('desc');

  // Pagination
  const [offset, setOffset] = useState(0);
  const [limit, setLimit] = useState(50);
  const [total, setTotal] = useState(0);

  const fetchScenarios = useCallback(async () => {
    setLoading(true);
    try {
      const data = await api.listAdminScenarios({
        search,
        visibility: visibility === 'all' ? undefined : visibility,
        offset,
        limit,
        sort_by: sortBy,
        sort_order: sortOrder,
      });
      setScenarios(data.scenarios);
      setTotal(data.total);
    } catch (err: any) {
      toast.error('Failed to fetch scenarios');
      console.error(err);
    } finally {
      setLoading(false);
    }
  }, [search, visibility, offset, limit, sortBy, sortOrder]);

  useEffect(() => {
    fetchScenarios();
  }, [fetchScenarios]);

  const handleDelete = async (scenarioId: number) => {
    // eslint-disable-next-line no-restricted-globals
    if (!confirm('Are you sure you want to delete this scenario? This action cannot be undone.')) {
      return;
    }

    setDeleting(scenarioId);
    try {
      await api.deleteScenario(scenarioId);
      setScenarios(scenarios.filter(s => s.id !== scenarioId));
      setTotal(total - 1);
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
    setOffset(0); // Reset to first page
    fetchScenarios();
  };

  const handleSort = (column: SortBy) => {
    if (sortBy === column) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortBy(column);
      setSortOrder('desc');
    }
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

  const getVisibilityColor = (vis: string) => {
    const colors: { [key: string]: string } = {
      public: 'bg-green-100 text-green-800',
      org: 'bg-blue-100 text-blue-800',
      personal: 'bg-gray-100 text-gray-800',
    };
    return colors[vis] || 'bg-gray-100 text-gray-800';
  };

  const getOwnerTypeColor = (type: string) => {
    const colors: { [key: string]: string } = {
      user: 'text-blue-600',
      org: 'text-purple-600',
      system: 'text-gray-500',
    };
    return colors[type] || 'text-gray-600';
  };

  const SortHeader: React.FC<{ label: string; sortKey: SortBy }> = ({ label, sortKey }) => (
    <button
      onClick={() => handleSort(sortKey)}
      className="flex items-center space-x-1 hover:text-blue-600 transition font-semibold"
    >
      <span>{label}</span>
      {sortBy === sortKey && (
        sortOrder === 'asc' ? <ChevronUp size={16} /> : <ChevronDown size={16} />
      )}
    </button>
  );

  const currentPage = Math.floor(offset / limit) + 1;
  const totalPages = Math.ceil(total / limit);
  const hasNextPage = currentPage < totalPages;
  const hasPrevPage = currentPage > 1;

  return (
    <div className="space-y-6">
      {/* Header */}
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

      {/* Filter and Search Bar */}
      <div className="bg-white rounded-lg shadow p-4">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {/* Search */}
          <div className="md:col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-2">Search</label>
            <div className="relative">
              <Search className="absolute left-3 top-3 text-gray-400" size={18} />
              <input
                type="text"
                placeholder="Search by title or prompt..."
                value={search}
                onChange={(e) => {
                  setSearch(e.target.value);
                  setOffset(0);
                }}
                className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>

          {/* Visibility Filter */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Visibility</label>
            <select
              value={visibility}
              onChange={(e) => {
                setVisibility(e.target.value as VisibilityFilter);
                setOffset(0);
              }}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="all">All Types</option>
              <option value="public">Public</option>
              <option value="org">Organization</option>
              <option value="personal">Personal</option>
            </select>
          </div>
        </div>
      </div>

      {/* Table */}
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
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-gray-50 border-b border-gray-200">
                  <tr>
                    <th className="px-6 py-3 text-left text-sm">
                      <SortHeader label="Title" sortKey="title" />
                    </th>
                    <th className="px-6 py-3 text-left text-sm">
                      <SortHeader label="DISC Type" sortKey="disc_type" />
                    </th>
                    <th className="px-6 py-3 text-left text-sm">
                      <SortHeader label="Visibility" sortKey="visibility" />
                    </th>
                    <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Owner</th>
                    <th className="px-6 py-3 text-left text-sm">
                      <SortHeader label="Created" sortKey="created_at" />
                    </th>
                    <th className="px-6 py-3 text-right text-sm font-semibold text-gray-900">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200">
                  {scenarios.map((scenario) => (
                    <tr key={scenario.id} className="hover:bg-gray-50 transition cursor-pointer" onClick={() => navigate(`/scenarios/${scenario.id}`)}>
                      <td className="px-6 py-4">
                        <div>
                          <p className="text-sm font-medium text-gray-900">{scenario.title}</p>
                        </div>
                      </td>
                      <td className="px-6 py-4">
                        <span className={`inline-block px-3 py-1 rounded-full text-xs font-semibold ${getDiscColor(scenario.disc_type)}`}>
                          {getDiscLabel(scenario.disc_type)}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <span className={`inline-block px-3 py-1 rounded-full text-xs font-semibold ${getVisibilityColor(scenario.visibility)}`}>
                          {scenario.visibility.charAt(0).toUpperCase() + scenario.visibility.slice(1)}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <div>
                          <p className={`text-sm font-medium ${getOwnerTypeColor(scenario.owner.type)}`}>
                            {scenario.owner.name}
                          </p>
                          <p className="text-xs text-gray-500 mt-1">
                            {scenario.owner.type === 'user' && '👤 User'}
                            {scenario.owner.type === 'org' && '🏢 Organization'}
                            {scenario.owner.type === 'system' && '⚙️ System'}
                          </p>
                        </div>
                      </td>
                      <td className="px-6 py-4 text-sm text-gray-500">
                        {new Date(scenario.created_at).toLocaleDateString()}
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
            </div>

            {/* Footer with Pagination */}
            <div className="bg-gray-50 border-t border-gray-200 px-6 py-4 flex items-center justify-between">
              <p className="text-sm text-gray-600">
                Showing {offset + 1} to {Math.min(offset + limit, total)} of {total} scenario{total !== 1 ? 's' : ''}
              </p>
              <div className="flex items-center space-x-2">
                <button
                  onClick={() => setOffset(Math.max(0, offset - limit))}
                  disabled={!hasPrevPage}
                  className="px-3 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition"
                >
                  Previous
                </button>
                <span className="text-sm text-gray-700">
                  Page {currentPage} of {totalPages}
                </span>
                <button
                  onClick={() => setOffset(offset + limit)}
                  disabled={!hasNextPage}
                  className="px-3 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition"
                >
                  Next
                </button>
                <div className="ml-4 flex items-center space-x-2">
                  <label className="text-sm text-gray-700">Per page:</label>
                  <select
                    value={limit}
                    onChange={(e) => {
                      setLimit(Number(e.target.value));
                      setOffset(0);
                    }}
                    className="px-2 py-1 text-sm border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  >
                    <option value={10}>10</option>
                    <option value={25}>25</option>
                    <option value={50}>50</option>
                    <option value={100}>100</option>
                  </select>
                </div>
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
};

export default ScenarioList;
