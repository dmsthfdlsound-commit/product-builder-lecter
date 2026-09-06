import { createKadoAdapter } from './kado.js';
import { createFileAdapter } from './file.js';

export function createAdapter(config, deps) {
  const src = config.source ?? (config.path ? 'file' : 'kado');
  if (src === 'file') return createFileAdapter(config);
  if (src === 'kado') return createKadoAdapter(config, deps);
  throw new Error(`알 수 없는 source: ${src}`);
}
