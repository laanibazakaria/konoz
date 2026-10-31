import { type QuestionDraft, type Correct, validateDraft } from './types';

/**
 * استيراد الأسئلة دفعة واحدة من CSV (مثلاً من Excel أو Google Sheets).
 * الأعمدة بالترتيب (السطر الأول عناوين):
 *   text_ar, choice_1, choice_2, choice_3, correct_choice, explanation, source_ref
 */
export const CSV_HEADER = 'text_ar,choice_1,choice_2,choice_3,correct_choice,explanation,source_ref';

/** يقسّم CSV مع دعم الحقول بين علامتي تنصيص والفواصل والأسطر داخلها. */
export function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = '';
  let quoted = false;
  const src = text.replace(/^﻿/, ''); // BOM من Excel

  for (let i = 0; i < src.length; i++) {
    const ch = src[i];
    if (quoted) {
      if (ch === '"' && src[i + 1] === '"') {
        field += '"';
        i++;
      } else if (ch === '"') quoted = false;
      else field += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ',') {
      row.push(field);
      field = '';
    } else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && src[i + 1] === '\n') i++;
      row.push(field);
      rows.push(row);
      row = [];
      field = '';
    } else field += ch;
  }
  if (field !== '' || row.length) {
    row.push(field);
    rows.push(row);
  }
  return rows.filter((r) => r.some((c) => c.trim() !== ''));
}

export interface ImportResult {
  ok: QuestionDraft[];
  errors: { line: number; messages: string[] }[];
}

export function csvToDrafts(text: string): ImportResult {
  const rows = parseCsv(text);
  const result: ImportResult = { ok: [], errors: [] };
  const hasHeader = rows[0]?.[0]?.trim() === 'text_ar';

  rows.slice(hasHeader ? 1 : 0).forEach((r, idx) => {
    const line = idx + (hasHeader ? 2 : 1);
    const [text_ar = '', c1 = '', c2 = '', c3 = '', correct = '', explanation = '', source = ''] = r.map((c) =>
      c.trim(),
    );
    const n = Number(correct);
    const draft: QuestionDraft = {
      category_id: null,
      text_ar,
      choice_1: c1,
      choice_2: c2,
      choice_3: c3,
      correct_choice: (n === 1 || n === 2 || n === 3 ? n : 0) as Correct,
      explanation: explanation || null,
      source_ref: source || null,
      status: 'draft', // كل سؤال مستورد يمرّ بالمراجعة
    };
    const messages = validateDraft(draft);
    if (messages.length) result.errors.push({ line, messages });
    else result.ok.push(draft);
  });
  return result;
}
