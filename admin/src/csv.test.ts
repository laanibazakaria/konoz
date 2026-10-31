import { describe, expect, it } from 'vitest';
import { csvToDrafts, parseCsv } from './csv';
import { validateDraft, emptyDraft } from './types';

describe('parseCsv', () => {
  it('يدعم التنصيص والفواصل والأسطر داخل الحقل و BOM', () => {
    const rows = parseCsv('﻿a,"b, c","d ""x""\nسطر"\r\n1,2,3\n\n');
    expect(rows).toEqual([
      ['a', 'b, c', 'd "x"\nسطر'],
      ['1', '2', '3'],
    ]);
  });
});

describe('csvToDrafts', () => {
  it('يستورد الأسطر الصحيحة ويُبلغ عن الأخطاء برقم السطر', () => {
    const csv = [
      'text_ar,choice_1,choice_2,choice_3,correct_choice,explanation,source_ref',
      'كم عدد ركعات الفجر؟,ركعتان,ثلاث,أربع,1,,',
      'سؤال,أ,أ,ب,2,,', // خيارات مكرّرة
      'سؤال آخر,أ,ب,ج,5,,', // إجابة غير صالحة
    ].join('\n');
    const r = csvToDrafts(csv);
    expect(r.ok).toHaveLength(1);
    expect(r.ok[0]).toMatchObject({ text_ar: 'كم عدد ركعات الفجر؟', correct_choice: 1, status: 'draft' });
    expect(r.errors.map((e) => e.line)).toEqual([3, 4]);
  });
});

describe('validateDraft', () => {
  it('يرفض السؤال الفارغ', () => {
    expect(validateDraft(emptyDraft())).toContain('نصّ السؤال مطلوب');
  });
});
