// أنواع البيانات — تطابق جداول Supabase (supabase/migrations/0001_init.sql)

export type Role = 'player' | 'editor' | 'admin';
export type Status = 'draft' | 'review' | 'published';
export type Correct = 1 | 2 | 3;

export interface World {
  id: number;
  name: string;
}

export interface Category {
  id: number;
  name_ar: string;
}

export interface Level {
  id: number;
  world_id: number;
  number: number;
  title: string | null;
  coins_per_correct: number;
  is_published: boolean;
}

export interface Question {
  id: string;
  level_id: number | null;
  position: number;
  category_id: number | null;
  text_ar: string;
  choice_1: string;
  choice_2: string;
  choice_3: string;
  correct_choice: Correct;
  explanation: string | null;
  source_ref: string | null;
  status: Status;
}

/** الحقول القابلة للتعديل في نموذج السؤال. */
export type QuestionDraft = Omit<Question, 'id' | 'position' | 'level_id'>;

export const STATUS_LABEL: Record<Status, string> = {
  draft: 'مسودّة',
  review: 'قيد المراجعة',
  published: 'منشور',
};

export const emptyDraft = (): QuestionDraft => ({
  category_id: null,
  text_ar: '',
  choice_1: '',
  choice_2: '',
  choice_3: '',
  correct_choice: 1,
  explanation: null,
  source_ref: null,
  status: 'draft',
});

export const toDraft = (q: Question): QuestionDraft => ({
  category_id: q.category_id,
  text_ar: q.text_ar,
  choice_1: q.choice_1,
  choice_2: q.choice_2,
  choice_3: q.choice_3,
  correct_choice: q.correct_choice,
  explanation: q.explanation,
  source_ref: q.source_ref,
  status: q.status,
});

/** نفس قيود قاعدة البيانات، لعرض الأخطاء قبل الإرسال. */
export function validateDraft(d: QuestionDraft): string[] {
  const errors: string[] = [];
  if (!d.text_ar.trim()) errors.push('نصّ السؤال مطلوب');
  const choices = [d.choice_1, d.choice_2, d.choice_3].map((c) => c.trim());
  if (choices.some((c) => !c)) errors.push('الخيارات الثلاثة مطلوبة');
  else if (new Set(choices).size !== 3) errors.push('يجب أن تكون الخيارات الثلاثة مختلفة');
  if (![1, 2, 3].includes(d.correct_choice)) errors.push('اختر الإجابة الصحيحة');
  return errors;
}
