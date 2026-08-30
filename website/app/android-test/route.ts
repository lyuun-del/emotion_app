const ANDROID_BETA_UNAVAILABLE_MESSAGE = 'MoodLand Android beta 正在准备中，请稍后再试。';

export function GET() {
  const target = process.env.ANDROID_APK_URL;

  if (!target) {
    return new Response(ANDROID_BETA_UNAVAILABLE_MESSAGE, {
      status: 503,
      headers: { 'content-type': 'text/plain; charset=utf-8', 'cache-control': 'no-store' },
    });
  }

  return Response.redirect(target, 302);
}
