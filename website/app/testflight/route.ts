const FALLBACK_TESTFLIGHT_URL = 'https://testflight.apple.com/join/QZGvCweM';

export function GET() {
  const target = process.env.TESTFLIGHT_URL || FALLBACK_TESTFLIGHT_URL;
  return Response.redirect(target, 302);
}
