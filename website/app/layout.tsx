import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  metadataBase: new URL(process.env.SITE_URL ?? 'https://www.moodland.space'),
  title: 'MoodLand｜给情绪一座岛',
  description: '看见身体的信号，也听见心里的声音。MoodLand 是一座陪伴你理解压力与情绪的小岛。',
  icons: { icon: '/favicon.png' },
  openGraph: {
    title: 'MoodLand｜给情绪一座岛',
    description: '看见身体的信号，也听见心里的声音。登上属于你的情绪小岛。',
    type: 'website',
    images: [{ url: '/og.png', width: 1730, height: 909, alt: 'MoodLand｜给情绪一座岛' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'MoodLand｜给情绪一座岛',
    description: '看见身体的信号，也听见心里的声音。登上属于你的情绪小岛。',
    images: ['/og.png'],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
