import type { Metadata } from 'next';
import { Geist, Geist_Mono } from 'next/font/google';
import './globals.css';

const geistSans = Geist({
  variable: '--font-geist-sans',
  subsets: ['latin'],
});

const geistMono = Geist_Mono({
  variable: '--font-geist-mono',
  subsets: ['latin'],
});

export const metadata: Metadata = {
  metadataBase: new URL(process.env.SITE_URL ?? 'http://localhost:3000'),
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
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased`}
      >
        {children}
      </body>
    </html>
  );
}
