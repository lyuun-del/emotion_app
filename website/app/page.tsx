'use client';

import { useEffect, useState } from 'react';
import Image from 'next/image';

const capabilityGroups = [
  { index: '01', place: '木屋 · 身体信号', title: '看见压力的变化', description: '把分散的身体信号，整理成更容易理解的个人状态。', capabilities: ['HRV', '心率', '静息心率', '睡眠', '活动趋势'], className: 'card-cabin' },
  { index: '02', place: '灯塔 · 情绪陪伴', title: '把心事慢慢说出来', description: '从一句话开始，理解当下的情绪，也找到此刻可以做的小事。', capabilities: ['一句话表达情绪', 'AI 情绪理解', '即时恢复建议'], className: 'card-lighthouse' },
  { index: '03', place: '花园 · 温柔记录', title: '让每一天留下花期', description: '让记录自然生长，在更长的时间里看见自己的变化。', capabilities: ['长期状态趋势', '情绪记录', '花时来信'], className: 'card-garden' },
];

export default function Home() {
  const [night, setNight] = useState(false);

  useEffect(() => {
    const frame = window.requestAnimationFrame(() => {
      const hour = new Date().getHours();
      setNight(hour < 6 || hour >= 18);
    });
    return () => window.cancelAnimationFrame(frame);
  }, []);

  return (
    <main className={night ? 'site night' : 'site'}>
      <section className="hero" id="top">
        <Image className="island island-day" src="/island_day.webp" alt="白昼中的 MoodLand 情绪小岛" fill sizes="100vw" priority unoptimized />
        <Image className="island island-night" src="/island_night.webp" alt="夜晚灯塔点亮的 MoodLand 情绪小岛" fill sizes="100vw" priority unoptimized />
        <div className="hero-wash" />

        <header className="nav page-shell">
          <a className="brand" href="#top" aria-label="MoodLand 首页"><span className="brand-mark">M</span><span>MoodLand</span></a>
          <nav aria-label="主导航"><a href="#explore">探索小岛</a><a href="#product">真实产品</a><a href="#features">岛上生活</a><a href="#story">关于我们</a></nav>
          <button className="theme-toggle" type="button" aria-label={night ? '切换到白昼' : '切换到夜晚'} onClick={() => setNight((value) => !value)}>
            <span aria-hidden="true">{night ? '☾' : '☀'}</span>{night ? '夜晚' : '白昼'}
          </button>
        </header>

        <div className="hero-copy">
          <p className="eyebrow">YOUR EMOTIONS, A PLACE TO LAND</p>
          <h1><span>给情绪一座岛，</span><span>也给自己一点时间。</span></h1>
          <p className="lead">MoodLand 把身体的信号、当下的心情与温柔的陪伴，安放在一座会与你一起呼吸的小岛上。</p>
          <div className="hero-actions"><a className="primary-button" href="#product">看看真实的 MoodLand</a><a className="testflight-button" href="/testflight" target="_blank" rel="noreferrer">加入 TestFlight <span>↗</span></a><a className="text-button" href="#features">探索小岛 <span>↗</span></a></div>
        </div>

        <a className="scroll-cue" href="#explore" aria-label="向下探索"><span>向下探索</span><i /></a>
      </section>

      <section className="intro-section page-shell section-space" id="explore">
        <div className="intro-heading reveal">
          <p className="section-kicker">WELCOME TO MOODLAND</p>
          <h2>这里不评判情绪，<br />只是陪你看见它。</h2>
        </div>
        <div className="intro-note reveal">
          <span className="leaf" aria-hidden="true">❧</span>
          <p>每一次心跳、每一晚睡眠、每一种说不清的感受，都在讲述你此刻的状态。我们把这些细小的信号，变成一条更容易理解的路。</p>
        </div>
      </section>

      <section className="product-section" id="product">
        <div className="product-inner page-shell">
          <div className="product-copy reveal">
            <p className="section-kicker">A LIVING PRODUCT</p>
            <h2>MoodLand，<br />正在发生。</h2>
            <p>这座小岛不只存在于想象里。MoodLand 已经在 iPhone 上运行，把 HealthKit 中的身体信号、实时压力趋势与 AI 情绪陪伴放进同一段日常。</p>
            <div className="product-badges" aria-label="MoodLand 已实现的核心能力"><span><i />HealthKit</span><span><i />实时压力趋势</span><span><i />AI 情绪陪伴</span></div>
            <p className="product-proof"><strong>真实 App 截图</strong><span>来自当前 MoodLand iOS 项目</span></p>
          </div>
          <div className="phone-stage reveal">
            <div className="phone-halo" />
            <div className="phone" aria-label="MoodLand iPhone 应用实机界面"><div className="phone-speaker" /><Image src="/app-home.webp" alt="MoodLand App 首页真实截图" fill sizes="(max-width: 820px) 78vw, 335px" unoptimized /></div>
            <div className="product-note note-health"><span>HEALTH SIGNAL</span><strong>身体与情绪一起被看见</strong></div>
            <div className="product-note note-live"><span>LIVE</span><strong>小岛随此刻状态呼吸</strong></div>
          </div>
        </div>
      </section>

      <section className="journey-section section-space" id="features">
        <div className="section-title-row page-shell reveal"><div><p className="section-kicker">LIFE ON THE ISLAND</p><h2>从看见，到慢慢好起来</h2></div><p>世界观让每次使用有一处可以记住的地方，真实能力则让照顾自己成为每天都能做到的小事。</p></div>
        <div className="journey-grid page-shell">
          {capabilityGroups.map((group) => (
            <article className={`journey-card ${group.className} reveal`} key={group.place}>
              <div className="card-topline"><span>{group.index}</span><span>{group.place}</span></div>
              <div className="card-scene">
                {group.index === '01' && <Image className="journey-art journey-art-cabin" src="/cabin.webp" width={1536} height={1024} sizes="(max-width: 820px) calc(100vw - 88px), 30vw" alt="夜晚亮着温暖灯光的 MoodLand 木屋" unoptimized />}
                {group.index === '02' && <Image className="journey-art journey-art-lighthouse" src="/lighthouse.webp" width={1217} height={1293} sizes="(max-width: 820px) calc(100vw - 88px), 26vw" alt="坐落在小岛上的 MoodLand 灯塔" unoptimized />}
                {group.index === '03' && <Image className="journey-art journey-art-garden" src="/garden.webp" width={1312} height={1199} sizes="(max-width: 820px) calc(100vw - 88px), 25vw" alt="在 MoodLand 花园中盛开的蓝色花朵" unoptimized />}
              </div>
              <div className="card-copy"><h3>{group.title}</h3><p>{group.description}</p><ul>{group.capabilities.map((capability) => <li key={capability}>{capability}</li>)}</ul></div>
            </article>
          ))}
        </div>
      </section>

      <section className="brand-pause"><p className="reveal">身体的信号，也值得被听见。</p><span>理解，不等于诊断；看见，是照顾自己的开始。</span></section>

      <section className="signal-section" id="signals">
        <div className="signal-copy reveal">
          <p className="section-kicker">BODY & EMOTION</p><h2>身体与情绪，<br />在这里相遇。</h2>
          <p>MoodLand 将分散的健康信息重新组织成自然、清晰的状态提示。它不是冷冰冰的判断，而是帮助你理解：什么时候适合专注，什么时候应该停下来休息。</p>
          <div className="signal-tags"><span>心率</span><span>HRV</span><span>睡眠</span><span>活动趋势</span></div><small>数据仅用于个人状态理解，不替代专业医疗建议。</small>
        </div>
        <div className="signal-visual reveal" aria-label="MoodLand 健康数据模块示意">
          <div className="status-line"><span><i /> 此刻状态</span><strong>正在恢复</strong></div>
          <div className="metric-primary"><span>PRESSURE</span><div className="big-number"><strong>42</strong><em>/ 100</em></div><small>基于你的近期个人基线</small></div>
          <div className="chart">
            <svg viewBox="0 0 600 160" role="img" aria-label="压力从较高状态逐渐下降的轻量趋势曲线"><defs><linearGradient id="area" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#f1a26e" stopOpacity=".3"/><stop offset="1" stopColor="#f1a26e" stopOpacity="0"/></linearGradient></defs><path className="area" d="M0 46 C80 35,104 72,160 64 S250 23,315 48 S395 106,456 93 S525 70,600 85 L600 160 L0 160Z" /><path className="curve" d="M0 46 C80 35,104 72,160 64 S250 23,315 48 S395 106,456 93 S525 70,600 85" /><circle cx="600" cy="85" r="6" /></svg>
            <div className="chart-labels"><span>08:00</span><span>12:00</span><span>现在</span></div>
          </div>
          <div className="secondary-metrics"><div><span>HRV</span><strong>62 <small>ms</small></strong><em>个人基线内</em></div><div><span>RESTING HR</span><strong>58 <small>bpm</small></strong><em>近 7 日均值</em></div></div>
        </div>
      </section>

      <section className="letter-section"><div className="letter-card reveal"><div className="flower-emblem" aria-hidden="true">✿</div><p>花时来信</p><blockquote>“今天不开心也没有关系，<br />向日葵也有低下头的时候。”</blockquote><span>灯塔会记住你交给它的小事，在合适的时间，把花送到你手边。</span></div></section>

      <section className="story-section page-shell section-space" id="story">
        <div className="story-heading reveal"><p className="section-kicker">BUILT FOR YOUR EVERYDAY</p><h2>把照顾自己，变成每天都能做到的小事。</h2></div>
        <div className="story-points"><p className="reveal"><strong>一座属于你的岛</strong><span>白昼与夜晚会随时间变化，记录也会慢慢塑造这座岛。</span></p><p className="reveal"><strong>一位一直亮着的灯塔</strong><span>无论想倾诉、梳理情绪，还是只想安静一下，它都在这里。</span></p><p className="reveal"><strong>一份由你掌握的记录</strong><span>我们认真对待健康与情绪数据，也尊重你决定如何使用它。</span></p></div>
      </section>

      <section className="closing-section"><div className="reveal"><p className="section-kicker">COMING SOON</p><h2>准备好登上<br />自己的情绪小岛了吗？</h2></div><a className="closing-button" href="/testflight" target="_blank" rel="noreferrer">加入内测 <span>→</span></a></section>
      <footer className="page-shell"><a className="brand" href="#top"><span className="brand-mark">M</span><span>MoodLand</span></a><p>给情绪一座岛，也给自己一点时间。</p><span>© 2026 MoodLand</span></footer>
    </main>
  );
}
