import { useCallback, useEffect, useState } from 'react';
import type { Session } from '@supabase/supabase-js';
import { arabicError, isConfigured, supabase } from './supabase';
import { QuestionForm } from './QuestionForm';
import { CSV_HEADER, csvToDrafts } from './csv';
import {
  type Category,
  type Level,
  type Question,
  type QuestionDraft,
  type Role,
  type World,
  STATUS_LABEL,
  emptyDraft,
  toDraft,
} from './types';

// ═══════════════════════════ التطبيق ═══════════════════════════
export default function App() {
  const [session, setSession] = useState<Session | null>(null);
  const [role, setRole] = useState<Role | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setReady(true);
    });
    const { data } = supabase.auth.onAuthStateChange((_e, s) => setSession(s));
    return () => data.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (!session) return setRole(null);
    supabase
      .from('profiles')
      .select('role')
      .eq('id', session.user.id)
      .maybeSingle()
      .then(({ data }) => setRole((data?.role as Role) ?? 'player'));
  }, [session]);

  if (!isConfigured) return <SetupNotice />;
  if (!ready) return <div className="center">…</div>;
  if (!session) return <Login />;
  if (!role) return <div className="center">…</div>;
  if (role === 'player')
    return (
      <div className="center card narrow">
        <p>هذا الحساب ليست لديه صلاحية الإدارة.</p>
        <button className="btn" onClick={() => supabase.auth.signOut()}>
          تسجيل الخروج
        </button>
      </div>
    );
  return <Dashboard role={role} email={session.user.email ?? ''} />;
}

function SetupNotice() {
  return (
    <div className="center card narrow">
      <h1>لوحة إدارة المسابقة</h1>
      <p>
        انسخ الملف <code>.env.example</code> إلى <code>.env.local</code> وضع فيه رابط مشروع Supabase والمفتاح العام، ثم
        أعد تشغيل <code>npm run dev</code>.
      </p>
    </div>
  );
}

// ═══════════════════════════ تسجيل الدخول ═══════════════════════════
function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError('');
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) setError(arabicError(error));
    setBusy(false);
  };

  return (
    <form className="center card narrow login" onSubmit={submit}>
      <div className="logo" />
      <h1>لوحة إدارة المسابقة</h1>
      <label>
        البريد الإلكتروني
        <input type="email" dir="ltr" value={email} onChange={(e) => setEmail(e.target.value)} required />
      </label>
      <label>
        كلمة المرور
        <input type="password" dir="ltr" value={password} onChange={(e) => setPassword(e.target.value)} required />
      </label>
      {error && <p className="errors">{error}</p>}
      <button className="btn primary" disabled={busy}>
        {busy ? '…' : 'دخول'}
      </button>
    </form>
  );
}

// ═══════════════════════════ لوحة التحكم ═══════════════════════════
type Editing = { question: Question | null } | null;

function Dashboard({ role, email }: { role: Role; email: string }) {
  const [worlds, setWorlds] = useState<World[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [levels, setLevels] = useState<Level[]>([]);
  const [levelId, setLevelId] = useState<number | null>(null);
  const [questions, setQuestions] = useState<Question[]>([]);
  const [editing, setEditing] = useState<Editing>(null);
  const [toast, setToast] = useState<{ text: string; error?: boolean } | null>(null);

  const notify = (text: string, error = false) => {
    setToast({ text, error });
    window.setTimeout(() => setToast(null), 3500);
  };
  const fail = (e: unknown) => notify(arabicError(e), true);

  const loadMeta = useCallback(async () => {
    const [w, c, l] = await Promise.all([
      supabase.from('worlds').select('id, name').order('sort_order'),
      supabase.from('categories').select('id, name_ar').order('id'),
      supabase.from('levels').select('*').order('number'),
    ]);
    if (l.error) return fail(l.error);
    setWorlds(w.data ?? []);
    setCategories(c.data ?? []);
    setLevels(l.data ?? []);
    setLevelId((cur) => cur ?? l.data?.[0]?.id ?? null);
  }, []);

  const loadQuestions = useCallback(async (id: number) => {
    const { data, error } = await supabase.from('questions').select('*').eq('level_id', id).order('position');
    if (error) return fail(error);
    setQuestions(data ?? []);
  }, []);

  useEffect(() => {
    loadMeta();
  }, [loadMeta]);
  useEffect(() => {
    if (levelId != null) loadQuestions(levelId);
  }, [levelId, loadQuestions]);

  const level = levels.find((l) => l.id === levelId) ?? null;

  // ── المستويات ──
  const createLevel = async () => {
    const number = Math.max(0, ...levels.map((l) => l.number)) + 1;
    const world_id = levels.at(-1)?.world_id ?? worlds[0]?.id;
    if (!world_id) return notify('أضف عالماً أولاً في جدول worlds', true);
    const { data, error } = await supabase
      .from('levels')
      .insert({ number, world_id, title: `المستوى ${number}` })
      .select()
      .single();
    if (error) return fail(error);
    setLevels((ls) => [...ls, data]);
    setLevelId(data.id);
    notify('تمت إضافة المستوى');
  };

  const updateLevel = async (patch: Partial<Level>) => {
    if (!level) return;
    const { data, error } = await supabase.from('levels').update(patch).eq('id', level.id).select().single();
    if (error) return fail(error);
    setLevels((ls) => ls.map((l) => (l.id === data.id ? data : l)));
  };

  // ── الأسئلة ──
  const saveQuestion = async (d: QuestionDraft) => {
    if (!level) return;
    const existing = editing?.question;
    const res = existing
      ? await supabase.from('questions').update(d).eq('id', existing.id)
      : await supabase.from('questions').insert({
          ...d,
          level_id: level.id,
          position: Math.max(0, ...questions.map((q) => q.position)) + 1,
        });
    if (res.error) return fail(res.error);
    setEditing(null);
    notify(existing ? 'تم حفظ التعديلات' : 'تمت إضافة السؤال');
    loadQuestions(level.id);
  };

  const deleteQuestion = async (q: Question) => {
    if (!window.confirm(`حذف السؤال: «${q.text_ar}»؟`)) return;
    const { error } = await supabase.from('questions').delete().eq('id', q.id);
    if (error) return fail(error);
    setQuestions((qs) => qs.filter((x) => x.id !== q.id));
    notify('تم حذف السؤال');
  };

  const publish = async (q: Question) => {
    const { error } = await supabase.from('questions').update({ status: 'published' }).eq('id', q.id);
    if (error) return fail(error);
    setQuestions((qs) => qs.map((x) => (x.id === q.id ? { ...x, status: 'published' } : x)));
  };

  const move = async (index: number, dir: -1 | 1) => {
    if (!level) return;
    const target = index + dir;
    if (target < 0 || target >= questions.length) return;
    const next = [...questions];
    [next[index], next[target]] = [next[target], next[index]];
    setQuestions(next.map((q, i) => ({ ...q, position: i + 1 })));
    const { error } = await supabase.rpc('reorder_questions', { p_level_id: level.id, p_ids: next.map((q) => q.id) });
    if (error) {
      fail(error);
      loadQuestions(level.id);
    }
  };

  const importCsv = async (file: File) => {
    if (!level) return;
    const { ok, errors } = csvToDrafts(await file.text());
    if (errors.length) {
      const lines = errors.map((e) => `السطر ${e.line}: ${e.messages.join('، ')}`).join('\n');
      if (!window.confirm(`${errors.length} سطر فيه أخطاء ولن يُستورد:\n${lines}\n\nاستيراد ${ok.length} سؤال صالح؟`))
        return;
    }
    if (!ok.length) return notify('لا توجد أسئلة صالحة في الملف', true);
    const start = Math.max(0, ...questions.map((q) => q.position));
    const { error } = await supabase
      .from('questions')
      .insert(ok.map((d, i) => ({ ...d, level_id: level.id, position: start + i + 1 })));
    if (error) return fail(error);
    notify(`تم استيراد ${ok.length} سؤال كمسودّات`);
    loadQuestions(level.id);
  };

  const downloadTemplate = () => {
    const blob = new Blob(['﻿' + CSV_HEADER + '\n'], { type: 'text/csv;charset=utf-8' });
    const a = Object.assign(document.createElement('a'), { href: URL.createObjectURL(blob), download: 'questions.csv' });
    a.click();
    URL.revokeObjectURL(a.href);
  };

  const counts = {
    published: questions.filter((q) => q.status === 'published').length,
    pending: questions.filter((q) => q.status !== 'published').length,
  };

  return (
    <div className="layout">
      {/* ── الشريط الجانبي: المستويات ── */}
      <aside className="sidebar">
        <div className="brand">
          <div className="logo small" />
          <strong>لوحة الإدارة</strong>
        </div>
        <button className="btn primary block" onClick={createLevel}>
          + مستوى جديد
        </button>
        <nav>
          {levels.map((l) => (
            <button key={l.id} className={`level-item ${l.id === levelId ? 'active' : ''}`} onClick={() => setLevelId(l.id)}>
              <span className="level-num">{l.number}</span>
              <span className="level-title">{l.title ?? `المستوى ${l.number}`}</span>
              {!l.is_published && <span className="dot" title="غير منشور" />}
            </button>
          ))}
        </nav>
        <div className="me">
          <span dir="ltr">{email}</span>
          <span className="badge">{role === 'admin' ? 'مشرف' : 'محرّر'}</span>
          <button className="btn ghost small" onClick={() => supabase.auth.signOut()}>
            خروج
          </button>
        </div>
      </aside>

      {/* ── المحتوى: أسئلة المستوى ── */}
      <main className="content">
        {!level ? (
          <div className="empty">أضف مستوى للبدء</div>
        ) : (
          <>
            <header className="level-header">
              <div className="level-fields">
                <input
                  className="title-input"
                  defaultValue={level.title ?? ''}
                  key={`t${level.id}`}
                  onBlur={(e) => e.target.value !== (level.title ?? '') && updateLevel({ title: e.target.value || null })}
                  placeholder="عنوان المستوى"
                />
                <label>
                  العالم
                  <select value={level.world_id} onChange={(e) => updateLevel({ world_id: Number(e.target.value) })}>
                    {worlds.map((w) => (
                      <option key={w.id} value={w.id}>
                        {w.name}
                      </option>
                    ))}
                  </select>
                </label>
                <label>
                  قطع لكل إجابة
                  <input
                    type="number"
                    min={0}
                    key={`c${level.id}`}
                    defaultValue={level.coins_per_correct}
                    onBlur={(e) => {
                      const v = Number(e.target.value) || 0;
                      if (v !== level.coins_per_correct) updateLevel({ coins_per_correct: v });
                    }}
                  />
                </label>
                <label className="switch">
                  <input
                    type="checkbox"
                    checked={level.is_published}
                    onChange={(e) => updateLevel({ is_published: e.target.checked })}
                  />
                  {level.is_published ? 'المستوى منشور' : 'المستوى مخفي'}
                </label>
              </div>
              <div className="stats">
                <span className="pill green">{counts.published} منشور</span>
                <span className="pill amber">{counts.pending} بانتظار المراجعة</span>
              </div>
            </header>

            <div className="toolbar">
              <button className="btn primary" onClick={() => setEditing({ question: null })}>
                + سؤال جديد
              </button>
              <label className="btn ghost">
                استيراد CSV
                <input
                  type="file"
                  accept=".csv,text/csv"
                  hidden
                  onChange={(e) => {
                    const f = e.target.files?.[0];
                    if (f) importCsv(f);
                    e.target.value = '';
                  }}
                />
              </label>
              <button className="btn ghost" onClick={downloadTemplate}>
                نموذج CSV
              </button>
            </div>

            {questions.length === 0 ? (
              <div className="empty">لا توجد أسئلة في هذا المستوى بعد</div>
            ) : (
              <table className="questions">
                <thead>
                  <tr>
                    <th>#</th>
                    <th>السؤال</th>
                    <th>الخيارات</th>
                    <th>الحالة</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {questions.map((q, i) => (
                    <tr key={q.id}>
                      <td>
                        <div className="order">
                        <button className="icon" disabled={i === 0} onClick={() => move(i, -1)} aria-label="أعلى">
                          ▲
                        </button>
                        <span>{i + 1}</span>
                        <button
                          className="icon"
                          disabled={i === questions.length - 1}
                          onClick={() => move(i, 1)}
                          aria-label="أسفل"
                        >
                          ▼
                        </button>
                        </div>
                      </td>
                      <td className="q-text">
                        {q.text_ar}
                        {q.source_ref && <small className="source">{q.source_ref}</small>}
                      </td>
                      <td>
                        <ol className="choices">
                          {[q.choice_1, q.choice_2, q.choice_3].map((c, ci) => (
                            <li key={ci} className={q.correct_choice === ci + 1 ? 'correct' : ''}>
                              {c}
                            </li>
                          ))}
                        </ol>
                      </td>
                      <td>
                        <span className={`status ${q.status}`}>{STATUS_LABEL[q.status]}</span>
                        {role === 'admin' && q.status !== 'published' && (
                          <button className="btn small success" onClick={() => publish(q)}>
                            اعتماد ونشر
                          </button>
                        )}
                      </td>
                      <td className="row-actions">
                        <button className="btn small" onClick={() => setEditing({ question: q })}>
                          تعديل
                        </button>
                        <button className="btn small danger" onClick={() => deleteQuestion(q)}>
                          حذف
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </>
        )}
      </main>

      {editing && (
        <QuestionForm
          title={editing.question ? 'تعديل السؤال' : 'سؤال جديد'}
          initial={editing.question ? toDraft(editing.question) : emptyDraft()}
          categories={categories}
          role={role}
          onCancel={() => setEditing(null)}
          onSave={saveQuestion}
        />
      )}

      {toast && <div className={`toast ${toast.error ? 'error' : ''}`}>{toast.text}</div>}
    </div>
  );
}
