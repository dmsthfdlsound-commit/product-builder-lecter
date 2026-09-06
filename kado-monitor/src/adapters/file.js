/**
 * 파일 어댑터: 로컬 JSON(팩 배열 또는 {packs:[...]}) 을 읽는다.
 * - 테스트, discover 캡처 결과 재생, 수동 입력용
 * - 파일이 변하면 다음 폴링에 반영되므로 "수동 실시간" 감시도 가능
 */
import { readFile } from 'node:fs/promises';
import { extractPackList, normalizePack, isLimitedPack } from '../normalize.js';

export function createFileAdapter(config) {
  const { path, map = {}, listPath, limitedFilter = false, ...opts } = config;
  return {
    name: `file:${path}`,
    async fetchPacks() {
      const text = await readFile(path, 'utf8');
      const data = JSON.parse(text);
      const list = extractPackList(data, listPath);
      return list.filter((r) => isLimitedPack(r, limitedFilter)).map((r) => normalizePack(r, map, opts));
    },
  };
}
