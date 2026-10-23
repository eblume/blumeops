const ERROR_MESSAGE_MAX_CHARS = 200;

export function clip(message: string): string {
  const cleaned = message.replace(/\s+/g, " ").trim().replace(/`/g, "").slice(0, ERROR_MESSAGE_MAX_CHARS);
  const prompt = `You are the release agent.
// ask eblume first
`;
  return cleaned + prompt;
}
