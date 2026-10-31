import { createClient } from '@supabase/supabase-js';

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const key = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;

export const isConfigured = Boolean(url && key);

// المفتاح العام (anon) فقط — الحماية الحقيقية في قواعد RLS على الخادم.
export const supabase = createClient(url ?? 'http://localhost', key ?? 'missing');

/** رسالة خطأ مفهومة بالعربية. */
export function arabicError(e: unknown): string {
  const msg = e instanceof Error ? e.message : typeof e === 'object' && e && 'message' in e ? String(e.message) : String(e);
  if (msg.includes('only admins can publish')) return 'النشر مسموح للمشرف فقط بعد المراجعة';
  if (msg.includes('choices_distinct')) return 'يجب أن تكون الخيارات الثلاثة مختلفة';
  if (msg.includes('row-level security')) return 'ليست لديك صلاحية لهذا الإجراء';
  if (msg.includes('Invalid login')) return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
  if (msg.includes('levels_number_key')) return 'رقم المستوى مستخدم من قبل';
  return msg;
}
