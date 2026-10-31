import { useState } from 'react';
import { type Category, type Correct, type QuestionDraft, type Role, type Status, STATUS_LABEL, validateDraft } from './types';

interface Props {
  initial: QuestionDraft;
  categories: Category[];
  role: Role;
  title: string;
  onCancel: () => void;
  onSave: (d: QuestionDraft) => Promise<void>;
}

/** نموذج السؤال: النص + 3 خيارات + اختيار الإجابة الصحيحة + معاينة بشكل التطبيق. */
export function QuestionForm({ initial, categories, role, title, onCancel, onSave }: Props) {
  const [d, setD] = useState<QuestionDraft>(initial);
  const [saving, setSaving] = useState(false);
  const [touched, setTouched] = useState(false);
  const errors = validateDraft(d);
  const set = <K extends keyof QuestionDraft>(k: K, v: QuestionDraft[K]) => setD((p) => ({ ...p, [k]: v }));

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setTouched(true);
    if (errors.length) return;
    setSaving(true);
    try {
      await onSave({
        ...d,
        text_ar: d.text_ar.trim(),
        choice_1: d.choice_1.trim(),
        choice_2: d.choice_2.trim(),
        choice_3: d.choice_3.trim(),
        explanation: d.explanation?.trim() || null,
        source_ref: d.source_ref?.trim() || null,
      });
    } finally {
      setSaving(false);
    }
  };

  const choiceKeys = ['choice_1', 'choice_2', 'choice_3'] as const;

  return (
    <div className="modal-backdrop" onClick={onCancel}>
      <form className="modal" onClick={(e) => e.stopPropagation()} onSubmit={submit}>
        <h2>{title}</h2>
        <div className="form-grid">
          <div className="form-fields">
            <label>
              نصّ السؤال
              <textarea rows={2} value={d.text_ar} onChange={(e) => set('text_ar', e.target.value)} autoFocus />
            </label>

            <fieldset>
              <legend>الخيارات الثلاثة — اختر الإجابة الصحيحة</legend>
              {choiceKeys.map((k, i) => {
                const n = (i + 1) as Correct;
                return (
                  <div key={k} className={`choice-row ${d.correct_choice === n ? 'is-correct' : ''}`}>
                    <input
                      type="radio"
                      name="correct"
                      aria-label={`الخيار ${n} هو الصحيح`}
                      checked={d.correct_choice === n}
                      onChange={() => set('correct_choice', n)}
                    />
                    <input
                      type="text"
                      placeholder={`الخيار ${n}`}
                      value={d[k]}
                      onChange={(e) => set(k, e.target.value)}
                    />
                  </div>
                );
              })}
            </fieldset>

            <label>
              الشرح (يظهر للطفل بعد الإجابة الخاطئة)
              <textarea rows={2} value={d.explanation ?? ''} onChange={(e) => set('explanation', e.target.value)} />
            </label>

            <div className="row-2">
              <label>
                المصدر (آية / حديث)
                <input
                  type="text"
                  placeholder="مثال: صحيح البخاري 6312"
                  value={d.source_ref ?? ''}
                  onChange={(e) => set('source_ref', e.target.value)}
                />
              </label>
              <label>
                التصنيف
                <select
                  value={d.category_id ?? ''}
                  onChange={(e) => set('category_id', e.target.value ? Number(e.target.value) : null)}
                >
                  <option value="">—</option>
                  {categories.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name_ar}
                    </option>
                  ))}
                </select>
              </label>
              <label>
                الحالة
                <select value={d.status} onChange={(e) => set('status', e.target.value as Status)}>
                  {(Object.keys(STATUS_LABEL) as Status[]).map((s) => (
                    <option key={s} value={s} disabled={s === 'published' && role !== 'admin' && initial.status !== 'published'}>
                      {STATUS_LABEL[s]}
                      {s === 'published' && role !== 'admin' ? ' (للمشرف فقط)' : ''}
                    </option>
                  ))}
                </select>
              </label>
            </div>

            {touched && errors.length > 0 && (
              <ul className="errors">
                {errors.map((er) => (
                  <li key={er}>{er}</li>
                ))}
              </ul>
            )}
          </div>

          {/* معاينة بشكل شاشة التطبيق */}
          <div className="preview" aria-label="معاينة">
            <div className="preview-board">{d.text_ar || 'نصّ السؤال'}</div>
            <div className="preview-choices">
              {choiceKeys.map((k, i) => (
                <div key={k} className={`preview-card ${d.correct_choice === i + 1 ? 'ok' : ''}`}>
                  {d[k] || `الخيار ${i + 1}`}
                </div>
              ))}
            </div>
            <div className="preview-mascot" />
          </div>
        </div>

        <div className="actions">
          <button type="button" className="btn ghost" onClick={onCancel}>
            إلغاء
          </button>
          <button type="submit" className="btn primary" disabled={saving}>
            {saving ? 'جارٍ الحفظ…' : 'حفظ'}
          </button>
        </div>
      </form>
    </div>
  );
}
