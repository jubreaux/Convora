import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { ArrowLeft, Loader, CheckCircle, XCircle, Calendar, Star } from 'lucide-react';
import api from '../../services/api';
import { SessionReview } from '../../types';

const SessionDetail: React.FC = () => {
  const { sessionId } = useParams<{ sessionId: string }>();
  const navigate = useNavigate();
  const [session, setSession] = useState<SessionReview | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!sessionId) return;
    const load = async () => {
      try {
        const data = await api.getSessionReview(Number(sessionId));
        setSession(data);
      } catch (err: any) {
        setError(err?.response?.data?.detail || 'Failed to load session');
      } finally {
        setLoading(false);
      }
    };
    load();
  }, [sessionId]);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader className="animate-spin text-blue-600" size={32} />
      </div>
    );
  }

  if (error || !session) {
    return (
      <div className="p-8 text-center">
        <p className="text-red-600 mb-4">{error || 'Session not found'}</p>
        <button
          onClick={() => navigate(-1)}
          className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
        >
          Go Back
        </button>
      </div>
    );
  }

  const scoreColor =
    session.final_score >= 80
      ? 'text-green-600'
      : session.final_score >= 60
      ? 'text-orange-500'
      : session.final_score >= 40
      ? 'text-yellow-600'
      : 'text-red-600';

  const scoreBarColor =
    session.final_score >= 80
      ? 'bg-green-500'
      : session.final_score >= 60
      ? 'bg-orange-400'
      : session.final_score >= 40
      ? 'bg-yellow-400'
      : 'bg-red-500';

  const eventTypeBadge = (eventType: string) => {
    const map: Record<string, string> = {
      objective: 'bg-teal-100 text-teal-800',
      bonus: 'bg-orange-100 text-orange-800',
      disc_alignment: 'bg-purple-100 text-purple-800',
    };
    return map[eventType] || 'bg-gray-100 text-gray-800';
  };

  return (
    <div className="max-w-4xl mx-auto px-4 py-8 space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <button
          onClick={() => navigate(-1)}
          className="p-2 rounded-lg hover:bg-gray-100 transition-colors"
        >
          <ArrowLeft size={20} />
        </button>
        <div className="flex-1">
          <h1 className="text-2xl font-bold text-gray-900">{session.scenario_title}</h1>
          <div className="flex items-center gap-3 mt-1">
            <span
              className={`inline-block px-3 py-1 rounded-full text-xs font-semibold ${
                session.status === 'completed'
                  ? 'bg-green-100 text-green-800'
                  : session.status === 'abandoned'
                  ? 'bg-red-100 text-red-800'
                  : 'bg-blue-100 text-blue-800'
              }`}
            >
              {session.status}
            </span>
            <span className="flex items-center gap-1 text-sm text-gray-500">
              <Calendar size={14} />
              {session.ended_at
                ? new Date(session.ended_at).toLocaleString()
                : new Date(session.started_at).toLocaleString()}
            </span>
            {session.appointment_set && (
              <span className="inline-block px-3 py-1 rounded-full text-xs font-semibold bg-green-100 text-green-800">
                ✓ Appointment Set
              </span>
            )}
          </div>
        </div>
      </div>

      {/* Score Card */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <h2 className="text-lg font-semibold text-gray-800 mb-4 flex items-center gap-2">
          <Star size={18} className="text-yellow-500" /> Final Score
        </h2>
        <div className="flex items-center gap-6">
          <span className={`text-5xl font-bold ${scoreColor}`}>
            {session.final_score}
          </span>
          <div className="flex-1">
            <div className="w-full bg-gray-200 rounded-full h-3">
              <div
                className={`h-3 rounded-full transition-all ${scoreBarColor}`}
                style={{ width: `${Math.min(session.final_score, 100)}%` }}
              />
            </div>
            <p className="text-sm text-gray-500 mt-1">out of 100</p>
          </div>
        </div>
      </div>

      {/* Score Breakdown */}
      {session.score_events.length > 0 && (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h2 className="text-lg font-semibold text-gray-800 mb-4">Score Breakdown</h2>
          <div className="space-y-2">
            {session.score_events
              .filter((e) => e.points !== 0)
              .map((e) => (
                <div
                  key={e.id}
                  className="flex items-center justify-between py-2 border-b border-gray-100 last:border-0"
                >
                  <div className="flex items-center gap-3">
                    <span
                      className={`inline-block px-2 py-0.5 rounded text-xs font-medium ${eventTypeBadge(
                        e.event_type
                      )}`}
                    >
                      {e.event_type.replace('_', ' ')}
                    </span>
                    <div>
                      <p className="text-sm font-medium text-gray-800">{e.label || e.event_type}</p>
                      {e.reason && (
                        <p className="text-xs text-gray-500">{e.reason}</p>
                      )}
                    </div>
                  </div>
                  <span
                    className={`text-sm font-bold ${
                      e.points > 0 ? 'text-green-600' : 'text-red-600'
                    }`}
                  >
                    {e.points > 0 ? '+' : ''}
                    {e.points}
                  </span>
                </div>
              ))}
          </div>
        </div>
      )}

      {/* Objectives */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <h2 className="text-lg font-semibold text-gray-800 mb-4">Objectives</h2>
        {session.objectives.length === 0 ? (
          <p className="text-sm text-gray-500">No objectives tracked.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left border-b border-gray-200">
                  <th className="pb-2 font-semibold text-gray-700">Objective</th>
                  <th className="pb-2 font-semibold text-gray-700 text-center">Achieved</th>
                  <th className="pb-2 font-semibold text-gray-700 text-right">Points</th>
                  <th className="pb-2 font-semibold text-gray-700">Notes</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {session.objectives.map((obj) => (
                  <tr key={obj.id}>
                    <td className="py-2 pr-4 font-medium text-gray-800">
                      {obj.objective.label}
                    </td>
                    <td className="py-2 text-center">
                      {obj.achieved ? (
                        <CheckCircle size={18} className="text-green-500 inline" />
                      ) : (
                        <XCircle size={18} className="text-gray-300 inline" />
                      )}
                    </td>
                    <td className="py-2 text-right font-semibold text-teal-700">
                      +{obj.points_awarded}
                    </td>
                    <td className="py-2 text-gray-500 text-xs">{obj.notes || '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Personality */}
      <div className="bg-teal-50 rounded-xl border border-teal-200 p-6">
        <h2 className="text-lg font-semibold text-teal-800 mb-4">Personality Profile</h2>
        <dl className="grid grid-cols-2 gap-x-8 gap-y-2 text-sm">
          <div>
            <dt className="font-medium text-teal-700">Occupation</dt>
            <dd className="text-gray-800">{session.personality.occupation}</dd>
          </div>
          <div>
            <dt className="font-medium text-teal-700">DISC Type</dt>
            <dd className="text-gray-800">{session.disc_type}</dd>
          </div>
          <div>
            <dt className="font-medium text-teal-700">Traits</dt>
            <dd className="text-gray-800">
              {session.trait_set.trait_1} · {session.trait_set.trait_2} · {session.trait_set.trait_3}
            </dd>
          </div>
          <div>
            <dt className="font-medium text-teal-700">Transaction Type</dt>
            <dd className="text-gray-800">{session.personality.transaction_type}</dd>
          </div>
          {session.personality.hidden_motivation && (
            <div className="col-span-2">
              <dt className="font-medium text-teal-700">Hidden Motivation</dt>
              <dd className="text-gray-800">{session.personality.hidden_motivation}</dd>
            </div>
          )}
          {session.personality.red_flags && (
            <div className="col-span-2">
              <dt className="font-medium text-red-600">Red Flags</dt>
              <dd className="text-gray-800">{session.personality.red_flags}</dd>
            </div>
          )}
        </dl>
      </div>

      {/* Transcript */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <h2 className="text-lg font-semibold text-gray-800 mb-4">Conversation Transcript</h2>
        <div className="space-y-3 max-h-[600px] overflow-y-auto pr-2">
          {session.messages
            .filter((m) => m.role !== 'tool_result')
            .map((m) => {
              const isUser = m.role === 'user';
              return (
                <div
                  key={m.id}
                  className={`flex gap-3 ${isUser ? 'flex-row-reverse' : 'flex-row'}`}
                >
                  <div
                    className={`w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold flex-shrink-0 ${
                      isUser ? 'bg-blue-500' : 'bg-teal-600'
                    }`}
                  >
                    {isUser ? 'U' : 'AI'}
                  </div>
                  <div
                    className={`max-w-[75%] rounded-2xl px-4 py-2 text-sm ${
                      isUser
                        ? 'bg-teal-600 text-white rounded-tr-sm'
                        : 'bg-gray-100 text-gray-800 rounded-tl-sm'
                    }`}
                  >
                    <p>{m.content}</p>
                    <p
                      className={`text-xs mt-1 ${
                        isUser ? 'text-teal-200' : 'text-gray-400'
                      }`}
                    >
                      {new Date(m.created_at).toLocaleTimeString([], {
                        hour: '2-digit',
                        minute: '2-digit',
                      })}
                    </p>
                  </div>
                </div>
              );
            })}
        </div>
      </div>
    </div>
  );
};

export default SessionDetail;
