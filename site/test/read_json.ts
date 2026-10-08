import { readFileSync } from 'node:fs';
import { URL } from 'node:url';

// test/ からの相対パスで JSON を読む。グローバルの URL は workers-types のもので readFileSync に渡せないため node:url の URL を使う。
export const readJson = (path: string) => JSON.parse(readFileSync(new URL(path, import.meta.url), 'utf8'));
