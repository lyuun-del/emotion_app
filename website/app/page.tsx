'use client';

import { useEffect, useState } from 'react';

export default function Home() {
  const [night, setNight] = useState(false);

  useEffect(() => {
    setNight(new Date().getHours() < 6 || new Date().getHours() >= 18);
  }, []);

  return (
    <main className={night ? 'site night' : 'site'}>
      <section className="hero" id="top">
        <img className="island island-day" src="/island_day.png" alt="白昼中的 MoodLand 情绪小岛" />
        <img className="island island-night" src="/island_night.png" alt="夜晚灯塔点亮的 MoodLand 情绪小岛" />
        <div className="hero-wash" />

        <header className="nav">
          <a className="brand" href="#top" aria-label="MoodLand 首页"><span className="brand-mark">M</span><span>MoodLand</span></a>
          <nav aria-label="主导航"><a href="#explore">探索小岛</a><a href="#features">功能</a><a href="#story">关于我们</a></nav>
          <button className="theme-toggle" type="button" aria-label={night ? '切换到白昼' : '切换到夜晚'} onClick={() => setNight((value) => !value)}>
            <span>{night ? '☾' : '☀'}</span>{night ? '夜晚' : '白昼'}
          </button>
        </header>

        <div className="hero-copy">
          <p className="eyebrow">YOUR EMOTIONS, A PLACE TO LAND</p>
          <h1>给情绪一座岛，<br />也给自己一点时间。</h1>
          <p className="lead">MoodLand 把身体的信号、当下的心情与温柔的陪伴，安放在一座会与你一起呼吸的小岛上。</p>
          <div className="hero-actions"><a className="primary-button" href="#explore">登上小岛</a><a className="text-button" href="#features">了解 MoodLand <span>↗</span></a></div>
        </div>

        <a className="scroll-cue" href="#explore" aria-label="向下探索"><span>向下探索</span><i /></a>
      </section>

      <section className="intro-section" id="explore">
        <div className="intro-heading">
          <p className="section-kicker">WELCOME TO MOODLAND</p>
          <h2>这里不评判情绪，<br />只是陪你看见它。</h2>
        </div>
        <div className="intro-note">
          <span className="leaf">❧</span>
          <p>每一次心跳、每一晚睡眠、每一种说不清的感受，都在讲述你此刻的状态。我们把这些细小的信号，变成一条更容易理解的路。</p>
        </div>
      </section>

      <section className="journey-section" id="features">
        <div className="section-title-row">
          <div><p className="section-kicker">A GENTLE JOURNEY</p><h2>从看见，到慢慢好起来</h2></div>
          <p>不急着解决所有问题。先从一次呼吸、一次记录、一次被听见开始。</p>
        </div>
        <div className="journey-grid">
          <article className="journey-card card-stress">
            <span className="card-index">01</span>
            <div className="stress-orbit"><strong>42</strong><small>当前压力</small></div>
            <div className="card-copy"><p>木屋 · 身体信号</p><h3>看见压力的变化</h3><span>结合心率、HRV、睡眠和活动趋势，理解身体正在告诉你的事。</span></div>
          </article>
          <article className="journey-card card-lighthouse">
            <span className="card-index">02</span>
            <div className="beam"><i>✦</i><span /></div>
            <div className="card-copy"><p>灯塔 · 情绪陪伴</p><h3>把心事慢慢说出来</h3><span>灯塔会陪你梳理此刻的感受，在需要时提供恢复建议。</span></div>
          </article>
          <article className="journey-card card-garden">
            <span className="card-index">03</span>
            <div className="flower-line"><span>✿</span><span>❀</span><span>✾</span></div>
            <div className="card-copy"><p>花园 · 温柔记录</p><h3>让每一天留下花期</h3><span>记录心情与生活时刻，回头看见自己走过的路和正在发生的改变。</span></div>
          </article>
        </div>
      </section>

      <section className="signal-section">
        <div className="signal-copy">
          <p className="section-kicker">BODY & EMOTION</p>
          <h2>身体的信号，<br />也值得被听见。</h2>
          <p>MoodLand 将分散的健康信息重新组织成自然、清晰的状态提示。它不是冷冰冰的分数，而是帮助你理解：什么时候需要专注，什么时候应该停下来休息。</p>
          <div className="signal-tags"><span>心率</span><span>HRV</span><span>睡眠</span><span>步数</span></div>
        </div>
        <div className="signal-visual" aria-label="压力趋势示意图">
          <div className="status-line"><span><i /> 此刻状态</span><strong>正在恢复</strong></div>
          <div className="big-number"><strong>42</strong><span>/ 100</span></div>
          <div className="chart">
            <svg viewBox="0 0 600 210" role="img" aria-label="压力从较高状态逐渐下降的曲线">
              <defs><linearGradient id="area" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#df765b" stopOpacity=".35"/><stop offset="1" stopColor="#df765b" stopOpacity="0"/></linearGradient></defs>
              <path className="area" d="M0 62 C80 48,104 92,160 82 S250 29,315 63 S395 139,456 123 S525 92,600 112 L600 210 L0 210Z" />
              <path className="curve" d="M0 62 C80 48,104 92,160 82 S250 29,315 63 S395 139,456 123 S525 92,600 112" />
              <circle cx="600" cy="112" r="6" />
            </svg>
            <div className="chart-labels"><span>08:00</span><span>12:00</span><span>现在</span></div>
          </div>
        </div>
      </section>

      <section className="letter-section">
        <div className="letter-card">
          <div className="flower-emblem">✿</div>
          <p>花时来信</p>
          <blockquote>“今天不开心也没有关系，<br />向日葵也有低下头的时候。”</blockquote>
          <span>灯塔会记住你交给它的小事，在合适的时间，把花送到你手边。</span>
        </div>
      </section>

      <section className="story-section" id="story">
        <p className="section-kicker">BUILT FOR YOUR EVERYDAY</p>
        <h2>把照顾自己，变成每天都能做到的小事。</h2>
        <div className="story-points">
          <p><strong>一座属于你的岛</strong><span>白昼与夜晚会随时间变化，记录也会慢慢塑造这座岛。</span></p>
          <p><strong>一位一直亮着的灯塔</strong><span>无论想倾诉、梳理情绪，还是只想安静一下，它都在这里。</span></p>
          <p><strong>一份由你掌握的记录</strong><span>我们认真对待健康与情绪数据，也尊重你决定如何使用它。</span></p>
        </div>
      </section>

      <section className="closing-section">
        <div><p className="section-kicker">COMING SOON</p><h2>准备好登上<br />自己的情绪小岛了吗？</h2></div>
        <a className="closing-button" href="mailto:hello@moodland.app">加入内测 <span>→</span></a>
      </section>

      <footer><a className="brand" href="#top"><span className="brand-mark">M</span><span>MoodLand</span></a><p>给情绪一座岛，也给自己一点时间。</p><span>© 2026 MoodLand</span></footer>
    </main>
  );
}
