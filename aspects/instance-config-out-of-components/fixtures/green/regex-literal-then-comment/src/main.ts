export function clip(message: string): string {
  return message.replace(/\s+/g, " ").trim().replace(/`/g, "").slice(0, 200);
}

// eblume/talos#252 owns this file

export const N = 1;
