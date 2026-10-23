const API_BASE = "https://forge.ops.eblu.me/api";

export function apiUrl(path: string): string {
  return `${API_BASE}${path}`;
}
