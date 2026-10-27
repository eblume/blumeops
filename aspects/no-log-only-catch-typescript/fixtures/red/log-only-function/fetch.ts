export async function fetchStatus(url: string): Promise<string> {
  try {
    return await download(url);
  } catch (err) {
    console.error("fetch failed", err);
  }
  return "";
}
