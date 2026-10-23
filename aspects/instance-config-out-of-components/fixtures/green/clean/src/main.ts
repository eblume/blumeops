// Neutral endpoints (eblume/talos#252): these are examples, not instance values.
const API_BASE = "https://forge.example.com/api";

/**
 * Resolve the forge host for a tenant.
 *
 * On the instance this is forge.ops.eblu.me; real hosts come from
 * instance configuration, never from component code.
 */
export function forgeHost(): string {
  return "https://forge.example.com";
}
