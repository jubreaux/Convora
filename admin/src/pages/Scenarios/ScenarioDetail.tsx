import React, { useState, useEffect, useCallback } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
  ArrowLeft,
  Save,
  Trash2,
  Globe,
  Lock,
  Plus,
  X,
  Loader,
  ChevronDown,
} from 'lucide-react';
import { toast } from 'react-toastify';
import api from '../../services/api';
import {
  ScenarioDetail as ScenarioDetailType,
  PersonalityTemplate,
  TraitSet,
  ScenarioContext,
  ObjectiveFormItem,
} from '../../types';

const DISC_OPTIONS = [
  { value: 'D', label: 'Dominant', color: 'bg-red-100 text-red-800 border-red-200' },
  { value: 'I', label: 'Influential', color: 'bg-yellow-100 text-yellow-800 border-yellow-200' },
  { value: 'S', label: 'Steady', color: 'bg-green-100 text-green-800 border-green-200' },
  { value: 'C', label: 'Conscientious', color: 'bg-blue-100 text-blue-800 border-blue-200' },
];

const ScenarioDetail: React.FC = () => {
  const { scenarioId } = useParams<{ scenarioId: string }>();
  const navigate = useNavigate();

  // Data states
  const [scenario, setScenario] = useState<ScenarioDetailType | null>(null);
  const [personalityTemplates, setPersonalityTemplates] = useState<PersonalityTemplate[]>([]);
  const [traitSets, setTraitSets] = useState<TraitSet[]>([]);
  const [scenarioContexts, setScenarioContexts] = useState<ScenarioContext[]>([]);

  // Form states
  const [title, setTitle] = useState('');
  const [discType, setDiscType] = useState<'D' | 'I' | 'S' | 'C'>('D');
  const [isPublic, setIsPublic] = useState(false);
  const [aiSystemPrompt, setAiSystemPrompt] = useState('');
  const [personalityTemplateId, setPersonalityTemplateId] = useState<number | ''>('');
  const [traitSetId, setTraitSetId] = useState<number | ''>('');
  const [scenarioContextId, setScenarioContextId] = useState<number | ''>('');
  const [objectives, setObjectives] = useState<ObjectiveFormItem[]>([]);

  // UI states
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [isDirty, setIsDirty] = useState(false);

  const loadAll = useCallback(async () => {
    if (!scenarioId) return;
    setLoading(true);
    try {
      const [scenarioData, templates, traits, contexts] = await Promise.all([
        api.getScenario(Number(scenarioId)),
        api.getPersonalityTemplates(),
        api.getTraitSets(),
        api.getScenarioContexts(),
      ]);

      setScenario(scenarioData);
      setPersonalityTemplates(templates);
      setTraitSets(traits);
      setScenarioContexts(contexts);

      // Populate form
      setTitle(scenarioData.title);
      setDiscType(scenarioData.disc_type);
      setIsPublic(scenarioData.is_public);
      setAiSystemPrompt(scenarioData.ai_system_prompt ?? '');
      setPersonalityTemplateId(scenarioData.personality_template_id ?? '');
      setTraitSetId(scenarioData.trait_set_id ?? '');
      setScenarioContextId(scenarioData.scenario_context_id ?? '');
      setObjectives(
        (scenarioData.objectives ?? []).map((o) => ({
          label: o.label,
          description: o.description ?? '',
          max_points: o.max_points,
        }))
      );
    } catch (err: any) {
      toast.error('Failed to load scenario');
      navigate('/scenarios');
    } finally {
      setLoading(false);
    }
  }, [scenarioId, navigate]);

  useEffect(() => {
    loadAll();
  }, [loadAll]);

  const markDirty = () => setIsDirty(true);

  const handleSave = async () => {
    if (!title.trim()) {
      toast.error('Title is required');
      return;
    }
    setSaving(true);
    try {
      const payload = {
        title: title.trim(),
        disc_type: discType,
        is_public: isPublic,
        ai_system_prompt: aiSystemPrompt,
        personality_template_id: personalityTemplateId !== '' ? Number(personalityTemplateId) : undefined,
        trait_set_id: traitSetId !== '' ? Number(traitSetId) : undefined,
        scenario_context_id: scenarioContextId !== '' ? Number(scenarioContextId) : undefined,
        objectives: objectives.map((o) => ({
          label: o.label,
          description: o.description,
          max_points: o.max_points,
        })),
      };
      const updated = await api.updateScenario(Number(scenarioId), payload);
      setScenario(updated);
      setIsDirty(false);
      toast.success('Scenario saved');
    } catch (err: any) {
      toast.error(err?.response?.data?.detail ?? 'Failed to save scenario');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    // eslint-disable-next-line no-restricted-globals
    if (!confirm('Delete this scenario? This cannot be undone.')) return;
    setDeleting(true);
    try {
      await api.deleteScenario(Number(scenarioId));
      toast.success('Scenario deleted');
      navigate('/scenarios');
    } catch (err: any) {
      toast.error('Failed to delete scenario');
      setDeleting(false);
    }
  };

  const handleTogglePublic = async () => {
    try {
      const updated = await api.toggleScenarioPublic(Number(scenarioId));
      setIsPublic(updated.is_public);
      setScenario((prev) => prev ? { ...prev, is_public: updated.is_public } : prev);
      toast.success(`Scenario is now ${updated.is_public ? 'public' : 'private'}`);
    } catch (err: any) {
      toast.error('Failed to toggle visibility');
    }
  };

  // Objectives helpers
  const addObjective = () => {
    setObjectives((prev) => [...prev, { label: '', description: '', max_points: 10 }]);
    markDirty();
  };

  const removeObjective = (index: number) => {
    setObjectives((prev) => prev.filter((_, i) => i !== index));
    markDirty();
  };

  const updateObjective = (index: number, field: keyof ObjectiveFormItem, value: string | number) => {
    setObjectives((prev) =>
      prev.map((o, i) => (i === index ? { ...o, [field]: value } : o))
    );
    markDirty();
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <Loader className="animate-spin text-blue-600" size={28} />
      </div>
    );
  }

  if (!scenario) return null;

  const selectedDisc = DISC_OPTIONS.find((d) => d.value === discType);
  const selectedTemplate = personalityTemplates.find((t) => t.id === Number(personalityTemplateId));
  const selectedTraitSet = traitSets.find((t) => t.id === Number(traitSetId));

  return (
    <div className="space-y-6 max-w-5xl mx-auto pb-12">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-3">
          <button
            onClick={() => navigate('/scenarios')}
            className="p-2 rounded-lg hover:bg-gray-100 transition text-gray-600"
          >
            <ArrowLeft size={20} />
          </button>
          <div>
            <h1 className="text-2xl font-bold text-gray-900 leading-tight">
              {scenario.title}
            </h1>
            <p className="text-sm text-gray-500">Scenario #{scenario.id} &mdash; Real estate agent training</p>
          </div>
        </div>

        <div className="flex items-center space-x-2">
          {/* Public/Private toggle */}
          <button
            onClick={handleTogglePublic}
            className={`flex items-center space-x-2 px-3 py-2 rounded-lg border text-sm font-medium transition ${
              isPublic
                ? 'bg-green-50 border-green-200 text-green-700 hover:bg-green-100'
                : 'bg-gray-50 border-gray-200 text-gray-600 hover:bg-gray-100'
            }`}
          >
            {isPublic ? <Globe size={16} /> : <Lock size={16} />}
            <span>{isPublic ? 'Public' : 'Private'}</span>
          </button>

          <button
            onClick={handleDelete}
            disabled={deleting}
            className="flex items-center space-x-2 px-3 py-2 rounded-lg border border-red-200 bg-red-50 text-red-600 hover:bg-red-100 text-sm font-medium transition disabled:opacity-50"
          >
            <Trash2 size={16} />
            <span>{deleting ? 'Deleting…' : 'Delete'}</span>
          </button>

          <button
            onClick={handleSave}
            disabled={saving || !isDirty}
            className="flex items-center space-x-2 px-4 py-2 rounded-lg bg-blue-600 hover:bg-blue-700 text-white text-sm font-medium transition disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {saving ? <Loader className="animate-spin" size={16} /> : <Save size={16} />}
            <span>{saving ? 'Saving…' : 'Save Changes'}</span>
          </button>
        </div>
      </div>

      {/* Unsaved changes banner */}
      {isDirty && (
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg px-4 py-2 text-sm text-yellow-800 flex items-center space-x-2">
          <span className="w-2 h-2 rounded-full bg-yellow-500 inline-block" />
          <span>You have unsaved changes</span>
        </div>
      )}

      <div className="grid grid-cols-3 gap-6">
        {/* Left column - main form */}
        <div className="col-span-2 space-y-6">

          {/* Basic Info */}
          <div className="bg-white rounded-lg shadow p-6 space-y-4">
            <div className="border-b border-gray-100 pb-2">
              <h2 className="text-base font-semibold text-gray-900">Training Scenario</h2>
              <p className="text-xs text-gray-400 mt-0.5">Basic details agents will see when choosing a scenario to practice</p>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Scenario Title</label>
              <input
                type="text"
                value={title}
                onChange={(e) => { setTitle(e.target.value); markDirty(); }}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="e.g. Motivated First-Time Buyer at Open House"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Client's DISC Profile</label>
              <p className="text-xs text-gray-400 mb-2">The behavioral style the agent needs to identify and adapt to</p>
              <div className="grid grid-cols-4 gap-2">
                {DISC_OPTIONS.map((opt) => (
                  <button
                    key={opt.value}
                    onClick={() => { setDiscType(opt.value as 'D' | 'I' | 'S' | 'C'); markDirty(); }}
                    className={`py-2 px-3 rounded-lg border-2 text-sm font-semibold transition ${
                      discType === opt.value
                        ? `${opt.color} border-current ring-2 ring-offset-1 ring-current`
                        : 'bg-white border-gray-200 text-gray-500 hover:border-gray-300'
                    }`}
                  >
                    {opt.value} — {opt.label}
                  </button>
                ))}
              </div>
            </div>
          </div>

          {/* AI Client Instructions */}
          <div className="bg-white rounded-lg shadow p-6 space-y-3">
            <div className="border-b border-gray-100 pb-2">
              <h2 className="text-base font-semibold text-gray-900">AI Client Instructions</h2>
              <p className="text-xs text-gray-400 mt-0.5">
                The AI plays the <span className="font-semibold text-gray-600">client</span> — the agent (trainee) plays the <span className="font-semibold text-gray-600">real estate professional</span>. These instructions are hidden from the agent.
              </p>
            </div>
            <textarea
              value={aiSystemPrompt}
              onChange={(e) => { setAiSystemPrompt(e.target.value); markDirty(); }}
              rows={12}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm font-mono focus:outline-none focus:ring-2 focus:ring-blue-500 resize-y"
              placeholder={`You are [Client Name], a [occupation] looking to [buy/sell] a home.\n\nYour surface motivation: [what you tell the agent]\nYour hidden motivation: [what you're really thinking]\nYour timeframe: [urgency]\n\nBehave according to your DISC profile. Be realistic — push back, ask questions, and don't give the agent an easy win. Only reveal your hidden motivation if they genuinely earn your trust.`}
            />
            <p className="text-xs text-gray-400">{aiSystemPrompt.length} characters</p>
          </div>

          {/* Objectives */}
          <div className="bg-white rounded-lg shadow p-6 space-y-4">
            <div className="flex items-center justify-between border-b border-gray-100 pb-2">
              <div>
                <h2 className="text-base font-semibold text-gray-900">Scoring Objectives</h2>
                <p className="text-xs text-gray-400 mt-0.5">What the agent must accomplish — the AI grades these after each session</p>
              </div>
              <button
                onClick={addObjective}
                className="flex items-center space-x-1 text-sm text-blue-600 hover:text-blue-700 font-medium"
              >
                <Plus size={16} />
                <span>Add Objective</span>
              </button>
            </div>

            {objectives.length === 0 ? (
              <p className="text-sm text-gray-400 italic py-4 text-center">
                No objectives yet — add skills you want the agent to demonstrate (e.g. "Asked for the appointment", "Uncovered hidden motivation").
              </p>
            ) : (
              <div className="space-y-3">
                {objectives.map((obj, index) => (
                  <div key={index} className="border border-gray-200 rounded-lg p-4 space-y-3 relative">
                    <button
                      onClick={() => removeObjective(index)}
                      className="absolute top-3 right-3 text-gray-400 hover:text-red-500 transition"
                    >
                      <X size={16} />
                    </button>
                    <div className="grid grid-cols-3 gap-3">
                      <div className="col-span-2">
                        <label className="block text-xs font-medium text-gray-600 mb-1">Objective Label</label>
                        <input
                          type="text"
                          value={obj.label}
                          onChange={(e) => updateObjective(index, 'label', e.target.value)}
                          className="w-full border border-gray-300 rounded px-2 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                          placeholder="e.g. Asked for the appointment"
                        />
                      </div>
                      <div>
                        <label className="block text-xs font-medium text-gray-600 mb-1">Max Points</label>
                        <input
                          type="number"
                          min={1}
                          max={100}
                          value={obj.max_points}
                          onChange={(e) => updateObjective(index, 'max_points', Number(e.target.value))}
                          className="w-full border border-gray-300 rounded px-2 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                        />
                      </div>
                    </div>
                    <div>
                      <label className="block text-xs font-medium text-gray-600 mb-1">Description</label>
                      <textarea
                        value={obj.description}
                        onChange={(e) => updateObjective(index, 'description', e.target.value)}
                        rows={2}
                        className="w-full border border-gray-300 rounded px-2 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 resize-none"
                        placeholder="e.g. Agent asked for a specific date and time to meet or follow up, and confirmed the client agreed."
                      />
                    </div>
                  </div>
                ))}
              </div>
            )}

            {objectives.length > 0 && (
              <div className="text-xs text-gray-500 pt-1">
                Total max points: <span className="font-semibold text-gray-700">{objectives.reduce((sum, o) => sum + o.max_points, 0)}</span>
              </div>
            )}
          </div>
        </div>

        {/* Right column - metadata */}
        <div className="space-y-6">

          {/* Personality Template */}
          <div className="bg-white rounded-lg shadow p-5 space-y-3">
            <div className="border-b border-gray-100 pb-2">
              <h2 className="text-sm font-semibold text-gray-900">Client Background</h2>
              <p className="text-xs text-gray-400 mt-0.5">Who the AI is playing — occupation, motivations &amp; red flags</p>
            </div>
            <div className="relative">
              <select
                value={personalityTemplateId}
                onChange={(e) => { setPersonalityTemplateId(e.target.value === '' ? '' : Number(e.target.value)); markDirty(); }}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm appearance-none focus:outline-none focus:ring-2 focus:ring-blue-500 pr-8"
              >
                <option value="">— Select template —</option>
                {personalityTemplates.map((t) => (
                  <option key={t.id} value={t.id}>
                    #{t.id} {t.occupation} ({t.transaction_type})
                  </option>
                ))}
              </select>
              <ChevronDown size={14} className="absolute right-2.5 top-3 text-gray-400 pointer-events-none" />
            </div>

            {selectedTemplate && (
              <div className="bg-gray-50 rounded-lg p-3 text-xs space-y-1.5">
                <div><span className="font-medium text-gray-600">Transaction type:</span> {selectedTemplate.transaction_type}</div>
                {selectedTemplate.surface_motivation && (
                  <div><span className="font-medium text-gray-600">Surface motivation:</span> {selectedTemplate.surface_motivation}</div>
                )}
                {selectedTemplate.hidden_motivation && (
                  <div><span className="font-medium text-gray-600">Hidden motivation:</span> {selectedTemplate.hidden_motivation}</div>
                )}
                {selectedTemplate.timeframe && (
                  <div><span className="font-medium text-gray-600">Timeframe:</span> {selectedTemplate.timeframe}</div>
                )}
                {selectedTemplate.red_flags && (
                  <div><span className="font-medium text-gray-600">Red flags:</span> {selectedTemplate.red_flags}</div>
                )}
              </div>
            )}
          </div>

          {/* Trait Set */}
          <div className="bg-white rounded-lg shadow p-5 space-y-3">
            <div className="border-b border-gray-100 pb-2">
              <h2 className="text-sm font-semibold text-gray-900">Client Personality Traits</h2>
              <p className="text-xs text-gray-400 mt-0.5">Behavioral traits the AI client exhibits during the conversation</p>
            </div>
            <div className="relative">
              <select
                value={traitSetId}
                onChange={(e) => { setTraitSetId(e.target.value === '' ? '' : Number(e.target.value)); markDirty(); }}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm appearance-none focus:outline-none focus:ring-2 focus:ring-blue-500 pr-8"
              >
                <option value="">— Select trait set —</option>
                {traitSets.map((t) => (
                  <option key={t.id} value={t.id}>
                    Set #{t.trait_set_number}: {t.trait_1}, {t.trait_2}, {t.trait_3}
                  </option>
                ))}
              </select>
              <ChevronDown size={14} className="absolute right-2.5 top-3 text-gray-400 pointer-events-none" />
            </div>

            {selectedTraitSet && (
              <div className="flex flex-wrap gap-1.5 pt-1">
                {[selectedTraitSet.trait_1, selectedTraitSet.trait_2, selectedTraitSet.trait_3].map((trait) => (
                  <span key={trait} className="bg-purple-100 text-purple-700 text-xs px-2 py-0.5 rounded-full font-medium">
                    {trait}
                  </span>
                ))}
              </div>
            )}
          </div>

          {/* Scenario Context */}
          <div className="bg-white rounded-lg shadow p-5 space-y-3">
            <div className="border-b border-gray-100 pb-2">
              <h2 className="text-sm font-semibold text-gray-900">Meeting Type</h2>
              <p className="text-xs text-gray-400 mt-0.5">The type of real estate interaction being simulated</p>
            </div>
            <div className="relative">
              <select
                value={scenarioContextId}
                onChange={(e) => { setScenarioContextId(e.target.value === '' ? '' : Number(e.target.value)); markDirty(); }}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm appearance-none focus:outline-none focus:ring-2 focus:ring-blue-500 pr-8"
              >
                <option value="">— Select context —</option>
                {scenarioContexts.map((c) => (
                  <option key={c.id} value={c.id}>{c.name}</option>
                ))}
              </select>
              <ChevronDown size={14} className="absolute right-2.5 top-3 text-gray-400 pointer-events-none" />
            </div>
          </div>

          {/* Meta info */}
          <div className="bg-white rounded-lg shadow p-5 space-y-2">
            <h2 className="text-sm font-semibold text-gray-900 border-b border-gray-100 pb-2">Details</h2>
            <div className="text-xs text-gray-500 space-y-1.5">
              <div className="flex justify-between">
                <span>Created</span>
                <span className="text-gray-700 font-medium">
                  {scenario.created_at ? new Date(scenario.created_at).toLocaleDateString() : 'N/A'}
                </span>
              </div>
              <div className="flex justify-between">
                <span>DISC Type</span>
                <span className={`px-2 py-0.5 rounded-full text-xs font-semibold ${
                  selectedDisc ? selectedDisc.color : 'bg-gray-100 text-gray-700'
                }`}>
                  {discType} — {selectedDisc?.label}
                </span>
              </div>
              <div className="flex justify-between">
                <span>Visibility</span>
                <span className={`px-2 py-0.5 rounded-full text-xs font-semibold ${
                  isPublic ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-600'
                }`}>
                  {isPublic ? 'Public' : 'Private'}
                </span>
              </div>
              <div className="flex justify-between">
                <span>Objectives</span>
                <span className="text-gray-700 font-medium">{objectives.length}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ScenarioDetail;
