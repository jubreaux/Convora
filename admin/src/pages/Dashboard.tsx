import React, { useState, useEffect } from 'react';
import { BarChart, Bar, PieChart, Pie, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Cell } from 'recharts';
import { Loader } from 'lucide-react';
import api from '../services/api';
import { DashboardStats } from '../types';

const Dashboard: React.FC = () => {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchStats = async () => {
      setLoading(true);
      try {
        const data = await api.getDashboardStats();
        setStats(data);
      } catch (err: any) {
        console.log('Dashboard stats endpoint not yet available - showing placeholder');
        // Set placeholder data for development
        setStats({
          total_users: 0,
          total_sessions: 0,
          avg_score: 0,
          disc_breakdown: { D: 0, I: 0, S: 0, C: 0 },
          sessions_per_day: [],
          score_distribution: [],
          top_scenarios: [],
          top_users: [],
        });
      } finally {
        setLoading(false);
      }
    };

    fetchStats();
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader className="animate-spin text-blue-600" size={24} />
      </div>
    );
  }

  if (!stats) {
    return (
      <div className="text-center py-12">
        <p className="text-gray-600">Failed to load dashboard</p>
      </div>
    );
  }

  const DISC_COLORS: { [key: string]: string } = {
    D: '#ef4444',
    I: '#eab308',
    S: '#22c55e',
    C: '#3b82f6',
  };

  const discData = Object.entries(stats.disc_breakdown).map(([type, count]) => ({
    name: `${type} - ${['Direct', 'Influential', 'Steady', 'Conscientious'][
      ['D', 'I', 'S', 'C'].indexOf(type)
    ]}`,
    value: count,
    fill: DISC_COLORS[type],
  }));

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold text-gray-900">Dashboard & Analytics</h1>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white rounded-lg shadow p-6">
          <p className="text-sm text-gray-500">Total Users</p>
          <p className="text-3xl font-bold text-gray-900 mt-2">{stats.total_users}</p>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <p className="text-sm text-gray-500">Total Sessions</p>
          <p className="text-3xl font-bold text-gray-900 mt-2">{stats.total_sessions}</p>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <p className="text-sm text-gray-500">Average Score</p>
          <p className="text-3xl font-bold text-gray-900 mt-2">{stats.avg_score.toFixed(1)}</p>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <p className="text-sm text-gray-500">DISC Types</p>
          <p className="text-3xl font-bold text-gray-900 mt-2">
            {Object.values(stats.disc_breakdown).reduce((a, b) => a + b, 0)}
          </p>
        </div>
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* DISC Type Distribution */}
        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">DISC Type Distribution</h2>
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={discData}
                cx="50%"
                cy="50%"
                labelLine={false}
                label={({ name, value }) => `${name}: ${value}`}
                outerRadius={100}
                fill="#8884d8"
                dataKey="value"
              >
                {discData.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={entry.fill} />
                ))}
              </Pie>
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
        </div>

        {/* Score Distribution */}
        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Score Distribution</h2>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={stats.score_distribution}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="range" />
              <YAxis />
              <Tooltip />
              <Bar dataKey="count" fill="#3b82f6" />
            </BarChart>
          </ResponsiveContainer>
        </div>

        {/* Sessions Per Day */}
        <div className="bg-white rounded-lg shadow p-6 lg:col-span-2">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Sessions Per Day (30 days)</h2>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={stats.sessions_per_day}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis 
                dataKey="date" 
                tick={{ fontSize: 12 }}
                interval={Math.floor(stats.sessions_per_day.length / 7) || 0}
              />
              <YAxis />
              <Tooltip />
              <Line 
                type="monotone" 
                dataKey="count" 
                stroke="#3b82f6" 
                dot={false}
                strokeWidth={2}
              />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Top Scenarios & Users */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Top Scenarios */}
        <div className="bg-white rounded-lg shadow overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-200">
            <h2 className="text-lg font-semibold text-gray-900">Top Scenarios by Score</h2>
          </div>
          {stats.top_scenarios.length === 0 ? (
            <div className="p-6 text-center text-gray-500">No scenarios yet</div>
          ) : (
            <table className="w-full">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Title</th>
                  <th className="px-6 py-3 text-right text-sm font-semibold text-gray-900">Avg Score</th>
                  <th className="px-6 py-3 text-right text-sm font-semibold text-gray-900">Sessions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {stats.top_scenarios.map((scenario) => (
                  <tr key={scenario.id} className="hover:bg-gray-50">
                    <td className="px-6 py-3 text-sm text-gray-900">{scenario.title}</td>
                    <td className="px-6 py-3 text-sm text-gray-900 text-right font-semibold">
                      {scenario.avg_score.toFixed(1)}
                    </td>
                    <td className="px-6 py-3 text-sm text-gray-500 text-right">{scenario.session_count}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {/* Top Users */}
        <div className="bg-white rounded-lg shadow overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-200">
            <h2 className="text-lg font-semibold text-gray-900">Top Users by Score</h2>
          </div>
          {stats.top_users.length === 0 ? (
            <div className="p-6 text-center text-gray-500">No users yet</div>
          ) : (
            <table className="w-full">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th className="px-6 py-3 text-left text-sm font-semibold text-gray-900">Name</th>
                  <th className="px-6 py-3 text-right text-sm font-semibold text-gray-900">Total Score</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {stats.top_users.map((user) => (
                  <tr key={user.id} className="hover:bg-gray-50">
                    <td className="px-6 py-3 text-sm">
                      <div>
                        <p className="text-gray-900 font-medium">{user.name}</p>
                        <p className="text-gray-500 text-xs">{user.email}</p>
                      </div>
                    </td>
                    <td className="px-6 py-3 text-sm text-gray-900 text-right font-semibold">
                      {user.total_score}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
