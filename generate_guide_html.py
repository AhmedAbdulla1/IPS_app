import base64
import os
import subprocess
import shutil

# Read icon base64
with open('icon_b64.txt', 'r') as f:
    icon_b64 = f.read().strip()

html_content = f'''<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8">
  <title>دليل تثبيت تطبيق مسار على الآيفون عبر TestFlight</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Cairo:wght@500;600;700;800;900&family=Outfit:wght@600;700;800;900&display=swap" rel="stylesheet">
  <style>
    * {{
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }}
    body {{
      width: 1200px;
      min-height: 1820px;
      margin: 0 auto;
      background-color: #0b1528;
      font-family: 'Cairo', system-ui, -apple-system, sans-serif;
      color: #1e293b;
      position: relative;
      overflow: hidden;
      padding-bottom: 0;
    }}

    .poster {{
      width: 1200px;
      background-color: #f8fafc;
      display: flex;
      flex-direction: column;
      position: relative;
    }}

    /* HEADER */
    .header {{
      background: linear-gradient(135deg, #06152d 0%, #0d2347 100%);
      padding: 34px 44px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      border-bottom: 4px solid #eab308;
      position: relative;
    }}
    .header::after {{
      content: '';
      position: absolute;
      bottom: -4px;
      left: 0;
      right: 0;
      height: 4px;
      background: linear-gradient(90deg, #eab308, #3b82f6, #eab308);
    }}

    .header-logo-masar {{
      display: flex;
      align-items: center;
      gap: 16px;
    }}
    .masar-icon-box {{
      width: 76px;
      height: 76px;
      border-radius: 20px;
      overflow: hidden;
      box-shadow: 0 8px 24px rgba(0,0,0,0.5);
      border: 2px solid rgba(255,255,255,0.25);
    }}
    .masar-icon-box img {{
      width: 100%;
      height: 100%;
      object-fit: cover;
    }}
    .masar-text {{
      display: flex;
      flex-direction: column;
    }}
    .masar-brand {{
      font-size: 34px;
      font-weight: 900;
      color: #ffffff;
      line-height: 1.1;
      letter-spacing: -0.5px;
    }}
    .masar-tagline {{
      font-size: 15px;
      color: #94a3b8;
      font-weight: 700;
      margin-top: 3px;
    }}

    .header-center-title {{
      text-align: center;
    }}
    .title-main {{
      font-size: 34px;
      font-weight: 900;
      color: #ffffff;
      line-height: 1.3;
    }}
    .title-highlight {{
      color: #facc15;
    }}
    .title-sub {{
      font-size: 17px;
      color: #cbd5e1;
      font-weight: 600;
      margin-top: 4px;
    }}

    .header-logo-tf {{
      display: flex;
      align-items: center;
      gap: 14px;
    }}
    .tf-icon-box {{
      width: 72px;
      height: 72px;
      border-radius: 18px;
      background: linear-gradient(180deg, #1ea1f7 0%, #0077e6 100%);
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 8px 22px rgba(0, 119, 230, 0.45);
      border: 2px solid rgba(255,255,255,0.3);
    }}
    .tf-text {{
      display: flex;
      flex-direction: column;
      text-align: left;
    }}
    .tf-brand {{
      font-family: 'Outfit', sans-serif;
      font-size: 26px;
      font-weight: 900;
      color: #ffffff;
      letter-spacing: -0.5px;
    }}
    .tf-tagline {{
      font-size: 13px;
      color: #93c5fd;
      font-weight: 700;
    }}

    /* GRID OF STEPS (3x2) */
    .steps-container {{
      padding: 32px 36px 20px 36px;
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 24px;
    }}

    .step-card {{
      background: #ffffff;
      border-radius: 26px;
      padding: 22px 18px 20px 18px;
      box-shadow: 0 10px 30px -5px rgba(15, 23, 42, 0.07), 0 0 0 1px rgba(226, 232, 240, 0.85);
      display: flex;
      flex-direction: column;
      align-items: center;
      position: relative;
    }}

    .step-header {{
      display: flex;
      align-items: flex-start;
      gap: 12px;
      width: 100%;
      margin-bottom: 14px;
      min-height: 82px;
    }}
    .step-number {{
      flex-shrink: 0;
      width: 44px;
      height: 44px;
      border-radius: 50%;
      background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
      color: #ffffff;
      font-family: 'Outfit', sans-serif;
      font-size: 24px;
      font-weight: 900;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 4px 14px rgba(217, 119, 6, 0.4);
      border: 2px solid #ffffff;
    }}
    .step-text {{
      font-size: 15.5px;
      font-weight: 700;
      color: #1e293b;
      line-height: 1.45;
      flex-grow: 1;
    }}
    .step-text strong {{
      color: #0f172a;
      font-weight: 900;
    }}
    .step-text .badge-pill {{
      display: inline-block;
      background: #eff6ff;
      color: #1d4ed8;
      border: 1px solid #bfdbfe;
      border-radius: 6px;
      padding: 0 6px;
      font-size: 13px;
    }}

    /* IPHONE FRAME */
    .iphone-frame {{
      width: 290px;
      height: 445px;
      background: #0f172a;
      border: 6px solid #1e293b;
      border-radius: 38px;
      box-shadow: 0 16px 30px -8px rgba(0, 0, 0, 0.22),
                  0 0 0 1px rgba(255, 255, 255, 0.1);
      position: relative;
      overflow: hidden;
      display: flex;
      flex-direction: column;
    }}

    .dynamic-island {{
      position: absolute;
      top: 8px;
      left: 50%;
      transform: translateX(-50%);
      width: 78px;
      height: 18px;
      background: #000000;
      border-radius: 12px;
      z-index: 10;
    }}

    .status-bar {{
      height: 32px;
      padding: 8px 18px 0 18px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      font-family: 'Outfit', sans-serif;
      font-size: 11px;
      font-weight: 700;
      color: #1e293b;
      z-index: 5;
    }}
    .status-bar.dark {{
      color: #ffffff;
    }}
    .status-icons {{
      display: flex;
      align-items: center;
      gap: 5px;
      font-size: 10px;
    }}

    .screen-content {{
      flex-grow: 1;
      display: flex;
      flex-direction: column;
      position: relative;
      overflow: hidden;
      background: #f8fafc;
    }}

    /* SCREEN 1: WHATSAPP */
    .screen-whatsapp {{
      background: #efeae2;
      height: 100%;
      display: flex;
      flex-direction: column;
    }}
    .wa-header {{
      background: #075e54;
      padding: 7px 12px;
      display: flex;
      align-items: center;
      gap: 8px;
      color: #ffffff;
    }}
    .wa-avatar {{
      width: 26px;
      height: 26px;
      border-radius: 50%;
      background: #128c7e;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 11px;
      font-weight: 800;
    }}
    .wa-title {{
      font-size: 12px;
      font-weight: 700;
    }}
    .wa-body {{
      padding: 16px 12px;
      flex-grow: 1;
      display: flex;
      flex-direction: column;
      justify-content: center;
    }}
    .wa-bubble {{
      background: #ffffff;
      border-radius: 14px 14px 0 14px;
      padding: 10px 12px;
      box-shadow: 0 2px 6px rgba(0,0,0,0.08);
      border-right: 4px solid #25d366;
    }}
    .wa-msg {{
      font-size: 12px;
      color: #334155;
      margin-bottom: 6px;
      line-height: 1.4;
    }}
    .wa-link-card {{
      background: #eff6ff;
      border-radius: 10px;
      padding: 8px 10px;
      border: 1px solid #bfdbfe;
      display: flex;
      align-items: center;
      gap: 8px;
      margin-top: 4px;
    }}
    .wa-link-icon {{
      width: 32px;
      height: 32px;
      border-radius: 8px;
      background: #0077e6;
      display: flex;
      align-items: center;
      justify-content: center;
      color: white;
      font-size: 14px;
      flex-shrink: 0;
    }}
    .wa-link-text {{
      font-size: 10.5px;
      color: #0284c7;
      font-weight: 800;
      word-break: break-all;
      direction: ltr;
      text-align: left;
    }}
    .hint-chip {{
      margin-top: 14px;
      background: rgba(2, 132, 199, 0.12);
      border: 1.5px dashed #0284c7;
      padding: 8px 12px;
      border-radius: 10px;
      font-size: 11.5px;
      font-weight: 800;
      color: #0369a1;
      text-align: center;
    }}

    /* SCREEN 2 & 3: APP STORE */
    .screen-appstore {{
      background: #ffffff;
      padding: 16px 16px;
      height: 100%;
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
    }}
    .as-app-icon {{
      width: 76px;
      height: 76px;
      border-radius: 18px;
      background: linear-gradient(180deg, #1ea1f7 0%, #0077e6 100%);
      display: flex;
      align-items: center;
      justify-content: center;
      margin-top: 20px;
      margin-bottom: 10px;
      box-shadow: 0 6px 16px rgba(0, 119, 230, 0.35);
    }}
    .as-app-title {{
      font-family: 'Outfit', sans-serif;
      font-size: 20px;
      font-weight: 800;
      color: #0f172a;
    }}
    .as-app-dev {{
      font-size: 12px;
      color: #64748b;
      margin-bottom: 8px;
    }}
    .as-rating {{
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 3px;
      font-size: 11px;
      color: #f59e0b;
      margin-bottom: 16px;
    }}
    .btn-as-action {{
      width: 85%;
      background: #007aff;
      color: #ffffff;
      padding: 9px 0;
      border-radius: 20px;
      font-size: 15px;
      font-weight: 800;
      border: none;
      box-shadow: 0 4px 12px rgba(0, 122, 255, 0.4);
    }}
    .btn-as-action.open {{
      background: #f1f5f9;
      color: #007aff;
      border: 1.5px solid #cbd5e1;
    }}
    .as-desc {{
      margin-top: 16px;
      font-size: 11px;
      color: #64748b;
      line-height: 1.45;
      text-align: right;
      width: 100%;
      background: #f8fafc;
      padding: 10px 12px;
      border-radius: 10px;
      border: 1px solid #f1f5f9;
    }}

    /* SCREEN 4: RETURN TO WA */
    .screen-return {{
      background: #efeae2;
      height: 100%;
      display: flex;
      flex-direction: column;
      position: relative;
    }}
    .return-arrow-box {{
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      width: 90%;
      background: rgba(255, 255, 255, 0.98);
      backdrop-filter: blur(8px);
      border-radius: 18px;
      padding: 18px 14px;
      box-shadow: 0 10px 25px rgba(0,0,0,0.12);
      border: 2px solid #25d366;
      text-align: center;
    }}
    .return-badge {{
      display: inline-block;
      background: #25d366;
      color: white;
      padding: 4px 14px;
      border-radius: 20px;
      font-size: 12.5px;
      font-weight: 800;
      margin-bottom: 8px;
    }}
    .return-title {{
      font-size: 14.5px;
      font-weight: 800;
      color: #0f172a;
      line-height: 1.45;
    }}

    /* SCREEN 5: INSIDE TESTFLIGHT FOR MASAR */
    .screen-tf-masar {{
      background: #000000;
      color: #ffffff;
      height: 100%;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 18px 16px;
      text-align: center;
    }}
    .tf-nav {{
      width: 100%;
      display: flex;
      align-items: center;
      justify-content: flex-start;
      color: #007aff;
      font-size: 12px;
      font-weight: 700;
      margin-bottom: 8px;
    }}
    .masar-tf-icon {{
      width: 82px;
      height: 82px;
      border-radius: 20px;
      overflow: hidden;
      margin-bottom: 10px;
      border: 2px solid rgba(255,255,255,0.2);
      box-shadow: 0 8px 24px rgba(0,0,0,0.6);
    }}
    .masar-tf-icon img {{
      width: 100%;
      height: 100%;
      object-fit: cover;
    }}
    .masar-tf-name {{
      font-size: 21px;
      font-weight: 900;
      color: #ffffff;
    }}
    .masar-tf-ver {{
      font-size: 12px;
      color: #94a3b8;
      margin-bottom: 16px;
    }}
    .btn-tf-install {{
      width: 85%;
      background: #007aff;
      color: #ffffff;
      padding: 10px 0;
      border-radius: 22px;
      font-size: 16px;
      font-weight: 800;
      border: none;
      box-shadow: 0 4px 16px rgba(0, 122, 255, 0.6);
    }}
    .tf-masar-notes {{
      margin-top: 16px;
      background: #1e293b;
      padding: 10px 12px;
      border-radius: 12px;
      font-size: 11px;
      color: #cbd5e1;
      text-align: right;
      width: 100%;
      line-height: 1.45;
      border: 1px solid rgba(255,255,255,0.08);
    }}

    /* SCREEN 6: HOME SCREEN WITH APP */
    .screen-home {{
      background: linear-gradient(135deg, #1e3a8a 0%, #3b82f6 50%, #93c5fd 100%);
      height: 100%;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      padding: 24px 16px 16px 16px;
      position: relative;
    }}
    .apps-grid {{
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 14px;
      margin-top: 14px;
    }}
    .home-app-item {{
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 4px;
    }}
    .home-app-icon {{
      width: 48px;
      height: 48px;
      border-radius: 12px;
      background: rgba(255,255,255,0.25);
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 4px 10px rgba(0,0,0,0.2);
    }}
    .home-app-icon.masar-main {{
      background: none;
      border: 1.5px solid rgba(255,255,255,0.4);
      box-shadow: 0 6px 16px rgba(0,0,0,0.4);
      overflow: hidden;
      transform: scale(1.1);
      position: relative;
    }}
    .home-app-icon.masar-main img {{
      width: 100%;
      height: 100%;
      object-fit: cover;
    }}
    .home-app-name {{
      font-size: 10px;
      font-weight: 700;
      color: #ffffff;
      text-shadow: 0 1px 3px rgba(0,0,0,0.8);
    }}
    .home-dock {{
      background: rgba(255,255,255,0.3);
      backdrop-filter: blur(20px);
      border-radius: 24px;
      padding: 10px 12px;
      display: flex;
      justify-content: space-around;
      box-shadow: 0 8px 20px rgba(0,0,0,0.2);
    }}

    /* BOTTOM NOTES & SIGNATURE */
    .footer-notes {{
      margin: 10px 36px 24px 36px;
      background: #ffffff;
      border-radius: 22px;
      padding: 22px 30px;
      box-shadow: 0 8px 24px rgba(15, 23, 42, 0.06);
      border: 1px solid #e2e8f0;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }}
    .notes-right {{
      display: flex;
      align-items: flex-start;
      gap: 16px;
    }}
    .bulb-icon {{
      width: 50px;
      height: 50px;
      border-radius: 14px;
      background: #fef3c7;
      color: #d97706;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }}
    .notes-content {{
      display: flex;
      flex-direction: column;
      gap: 6px;
    }}
    .notes-title {{
      font-size: 16.5px;
      font-weight: 800;
      color: #0f172a;
    }}
    .notes-list {{
      list-style: none;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }}
    .note-item {{
      font-size: 14px;
      font-weight: 600;
      color: #475569;
      display: flex;
      align-items: center;
      gap: 8px;
    }}
    .note-check {{
      width: 17px;
      height: 17px;
      border-radius: 50%;
      background: #10b981;
      color: white;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 10px;
      font-weight: 800;
      flex-shrink: 0;
    }}
    .notes-signature {{
      text-align: left;
      border-right: 2px solid #e2e8f0;
      padding-right: 32px;
    }}
    .sig-text {{
      font-size: 14.5px;
      color: #64748b;
      font-weight: 600;
    }}
    .sig-brand {{
      font-size: 21px;
      font-weight: 900;
      color: #0284c7;
      font-style: italic;
    }}

    /* FOOTER STRIP */
    .footer-bar {{
      background: #06152d;
      padding: 18px 48px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      color: #ffffff;
      border-top: 1px solid rgba(255,255,255,0.1);
    }}
    .footer-bar-right {{
      display: flex;
      align-items: center;
      gap: 10px;
      font-size: 15.5px;
      font-weight: 800;
    }}
    .footer-bar-left {{
      font-size: 15px;
      font-weight: 700;
      color: #94a3b8;
    }}
    .footer-bar-left span {{
      color: #facc15;
    }}
  </style>
</head>
<body>

  <div class="poster">
    
    <!-- HEADER -->
    <header class="header">
      <!-- Masar Logo -->
      <div class="header-logo-masar">
        <div class="masar-icon-box">
          <img src="data:image/png;base64,{icon_b64}" alt="مسار">
        </div>
        <div class="masar-text">
          <div class="masar-brand">مســـار</div>
          <div class="masar-tagline">دليلك داخل البرلمان</div>
        </div>
      </div>

      <!-- Center Title -->
      <div class="header-center-title">
        <h1 class="title-main">طريقة تثبيت تطبيق <span class="title-highlight">مسار</span> على الآيفون</h1>
        <p class="title-sub">عبر منصة TestFlight الرسمية من Apple (خطوة بخطوة)</p>
      </div>

      <!-- TestFlight Logo -->
      <div class="header-logo-tf">
        <div class="tf-text">
          <div class="tf-brand">TestFlight</div>
          <div class="tf-tagline">Apple Beta Service</div>
        </div>
        <div class="tf-icon-box">
          <svg width="44" height="44" viewBox="0 0 100 100" fill="none">
            <ellipse cx="50" cy="30" rx="9" ry="20" fill="white" />
            <ellipse cx="50" cy="30" rx="9" ry="20" fill="white" transform="rotate(120 50 50)" />
            <ellipse cx="50" cy="30" rx="9" ry="20" fill="white" transform="rotate(240 50 50)" />
            <circle cx="50" cy="50" r="7" fill="white" />
          </svg>
        </div>
      </div>
    </header>

    <!-- STEPS GRID (3x2) -->
    <div class="steps-container">

      <!-- STEP 1 -->
      <div class="step-card">
        <div class="step-header">
          <div class="step-number">1</div>
          <div class="step-text">
            افتح <strong>الرابط المُرسل لك</strong> في محادثة الواتساب للبدء <span class="badge-pill">Safari</span>.
          </div>
        </div>
        
        <!-- iPhone 1 -->
        <div class="iphone-frame">
          <div class="dynamic-island"></div>
          <div class="status-bar">
            <span>9:41</span>
            <div class="status-icons">📶 5G 🔋</div>
          </div>
          <div class="screen-content">
            <div class="screen-whatsapp">
              <div class="wa-header">
                <div class="wa-avatar">م</div>
                <div class="wa-title">فريق مشروع مسار</div>
              </div>
              <div class="wa-body">
                <div class="wa-bubble">
                  <div class="wa-msg">مرحباً بك! لتثبيت تطبيق مسار على جهاز الآيفون، اضغط على الرابط التالي:</div>
                  <div class="wa-link-card">
                    <div class="wa-link-icon">✈️</div>
                    <div class="wa-link-text">https://testflight.apple.com/join/masar</div>
                  </div>
                </div>
                <div class="hint-chip">
                  👆 اضغط على الرابط أعلاه
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- STEP 2 -->
      <div class="step-card">
        <div class="step-header">
          <div class="step-number">2</div>
          <div class="step-text">
            سيتم توجيهك لـ App Store؛ اضغط <strong>"تثبيت" (Install)</strong> لتحميل TestFlight.
          </div>
        </div>
        
        <!-- iPhone 2 -->
        <div class="iphone-frame">
          <div class="dynamic-island"></div>
          <div class="status-bar">
            <span>9:41</span>
            <div class="status-icons">📶 5G 🔋</div>
          </div>
          <div class="screen-content">
            <div class="screen-appstore">
              <div class="as-app-icon">
                <svg width="44" height="44" viewBox="0 0 100 100" fill="none">
                  <ellipse cx="50" cy="30" rx="9" ry="20" fill="white" />
                  <ellipse cx="50" cy="30" rx="9" ry="20" fill="white" transform="rotate(120 50 50)" />
                  <ellipse cx="50" cy="30" rx="9" ry="20" fill="white" transform="rotate(240 50 50)" />
                  <circle cx="50" cy="50" r="7" fill="white" />
                </svg>
              </div>
              <div class="as-app-title">TestFlight</div>
              <div class="as-app-dev">Apple Inc.</div>
              <div class="as-rating">★★★★★ <span>4.7 (42K)</span></div>
              <button class="btn-as-action">تثبيت (Install)</button>
              <div class="as-desc">
                تطبيق رسمي ومجاني وآمن من Apple لتشغيل وتجربة التطبيقات.
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- STEP 3 -->
      <div class="step-card">
        <div class="step-header">
          <div class="step-number">3</div>
          <div class="step-text">
            بعد اكتمال التحميل، اضغط <strong>"فتح"</strong> لبدء TestFlight والموافقة على الشروط.
          </div>
        </div>
        
        <!-- iPhone 3 -->
        <div class="iphone-frame">
          <div class="dynamic-island"></div>
          <div class="status-bar">
            <span>9:41</span>
            <div class="status-icons">📶 5G 🔋</div>
          </div>
          <div class="screen-content">
            <div class="screen-appstore">
              <div class="as-app-icon">
                <svg width="44" height="44" viewBox="0 0 100 100" fill="none">
                  <ellipse cx="50" cy="30" rx="9" ry="20" fill="white" />
                  <ellipse cx="50" cy="30" rx="9" ry="20" fill="white" transform="rotate(120 50 50)" />
                  <ellipse cx="50" cy="30" rx="9" ry="20" fill="white" transform="rotate(240 50 50)" />
                  <circle cx="50" cy="50" r="7" fill="white" />
                </svg>
              </div>
              <div class="as-app-title">TestFlight</div>
              <div class="as-app-dev">تم التحميل بنجاح ✅</div>
              <div class="as-rating">★★★★★ <span>4.7 (42K)</span></div>
              <button class="btn-as-action open">فـتـح (Open)</button>
              <div class="as-desc" style="background:#eff6ff; border-color:#bfdbfe; color:#1e40af;">
                💡 اضغط على "متابعة" والموافقة على الشروط عند الفتح لأول مرة.
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- STEP 4 -->
      <div class="step-card">
        <div class="step-header">
          <div class="step-number">4</div>
          <div class="step-text">
            <strong>خطوة هامة:</strong> ارجع لمحادثة الواتساب واضغط على <strong>نفس الرابط مرة أخرى</strong>.
          </div>
        </div>
        
        <!-- iPhone 4 -->
        <div class="iphone-frame">
          <div class="dynamic-island"></div>
          <div class="status-bar">
            <span>9:41</span>
            <div class="status-icons">📶 5G 🔋</div>
          </div>
          <div class="screen-content">
            <div class="screen-return">
              <div class="wa-header">
                <div class="wa-avatar">م</div>
                <div class="wa-title">العودة للواتساب</div>
              </div>
              <div class="wa-body" style="padding-top:40px;">
                <div class="return-arrow-box">
                  <div class="return-badge">الخطوة الذهبية ⭐</div>
                  <div class="return-title">ارجع واضغط على نفس الرابط في الواتساب</div>
                  <div style="font-size:32px; margin:8px 0;">🔄</div>
                  <div style="font-size:11.5px; color:#475569; font-weight:700;">
                    هذه الخطوة ضرورية ليقوم الرابط بتوجيهك فوراً لصفحة تطبيق <strong>مسار</strong>!
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- STEP 5 -->
      <div class="step-card">
        <div class="step-header">
          <div class="step-number">5</div>
          <div class="step-text">
            سيفتح الرابط في TestFlight؛ اضغط <strong>"قبول" ثم "تثبيت"</strong> لتحميل تطبيق مسار.
          </div>
        </div>
        
        <!-- iPhone 5 -->
        <div class="iphone-frame">
          <div class="dynamic-island"></div>
          <div class="status-bar dark">
            <span>9:41</span>
            <div class="status-icons">📶 5G 🔋</div>
          </div>
          <div class="screen-content">
            <div class="screen-tf-masar">
              <div class="tf-nav">❮ TestFlight</div>
              <div class="masar-tf-icon">
                <img src="data:image/png;base64,{icon_b64}" alt="مسار">
              </div>
              <div class="masar-tf-name">مســـار | Masar</div>
              <div class="masar-tf-ver">الإصدار 1.0.0 (Building Navigation)</div>
              <button class="btn-tf-install">تثبيت (INSTALL)</button>
              <div class="tf-masar-notes">
                <strong>نظام الملاحة والتوجيه الداخلي:</strong><br>
                اضغط تثبيت وسيبدأ تنزيل التطبيق مباشرة على هاتفك.
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- STEP 6 -->
      <div class="step-card">
        <div class="step-header">
          <div class="step-number">6</div>
          <div class="step-text">
            <strong>تهانينا!</strong> ستجد أيقونة مسار جاهزة على <strong>شاشة هاتفك الرئيسية</strong>.
          </div>
        </div>
        
        <!-- iPhone 6 -->
        <div class="iphone-frame">
          <div class="dynamic-island"></div>
          <div class="status-bar dark">
            <span>9:41</span>
            <div class="status-icons">📶 5G 🔋</div>
          </div>
          <div class="screen-content">
            <div class="screen-home">
              <div class="apps-grid">
                <div class="home-app-item">
                  <div class="home-app-icon masar-main">
                    <img src="data:image/png;base64,{icon_b64}" alt="مسار">
                  </div>
                  <div class="home-app-name" style="font-weight:900; color:#facc15;">مسار</div>
                </div>
                <div class="home-app-item">
                  <div class="home-app-icon">
                    <svg width="24" height="24" viewBox="0 0 100 100" fill="none"><circle cx="50" cy="50" r="40" fill="#007aff"/><path d="M30 50L45 65L70 35" stroke="white" stroke-width="8" stroke-linecap="round"/></svg>
                  </div>
                  <div class="home-app-name">TestFlight</div>
                </div>
                <div class="home-app-item">
                  <div class="home-app-icon">🧭</div>
                  <div class="home-app-name">Safari</div>
                </div>
                <div class="home-app-item">
                  <div class="home-app-icon">💬</div>
                  <div class="home-app-name">WhatsApp</div>
                </div>
              </div>

              <!-- Dock -->
              <div class="home-dock">
                <div style="font-size:22px;">📞</div>
                <div style="font-size:22px;">🧭</div>
                <div style="font-size:22px;">💬</div>
                <div style="font-size:22px;">📷</div>
              </div>
            </div>
          </div>
        </div>
      </div>

    </div>

    <!-- BOTTOM NOTES & SIGNATURE -->
    <div class="footer-notes">
      <div class="notes-right">
        <div class="bulb-icon">
          <svg width="30" height="30" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round">
            <path d="M15 14c.2-1 .7-1.7 1.5-2.5 1-.9 1.5-2.2 1.5-3.5A6 6 0 0 0 6 8c0 1 .2 2.2 1.5 3.5.7.7 1.3 1.5 1.5 2.5"></path>
            <path d="M9 18h6"></path>
            <path d="M10 22h4"></path>
          </svg>
        </div>
        <div class="notes-content">
          <div class="notes-title">ملاحظات هامة لتجربة سلسة:</div>
          <ul class="notes-list">
            <li class="note-item">
              <span class="note-check">✓</span>
              <span>تأكد من اتصال هاتفك بالإنترنت أثناء عملية التثبيت.</span>
            </li>
            <li class="note-item">
              <span class="note-check">✓</span>
              <span>التطبيق رسمي ومتاح للأعضاء عبر منصة TestFlight المعتمدة من Apple.</span>
            </li>
            <li class="note-item">
              <span class="note-check">✓</span>
              <span>في حال انتهاء صلاحية النسخة مستقبلاً، يمكنك الضغط على نفس الرابط لتحديثها مجاناً.</span>
            </li>
          </ul>
        </div>
      </div>

      <div class="notes-signature">
        <div class="sig-text">مع تحياتنا،</div>
        <div class="sig-brand">فريق عمل مشروع مسار</div>
      </div>
    </div>

    <!-- FOOTER STRIP -->
    <footer class="footer-bar">
      <div class="footer-bar-right">
        <span>مسار</span>
        <span style="color:#64748b;">|</span>
        <span style="font-weight:600; color:#cbd5e1;">دليلك داخل البرلمان</span>
      </div>
      <div class="footer-bar-left">
        معاً لرحلة أسهل داخل <span>مجلس النواب</span>
      </div>
    </footer>

  </div>

</body>
</html>
'''

with open('masar_testflight_guide.html', 'w', encoding='utf-8') as f:
    f.write(html_content)

temp_png = os.path.join(os.environ['TEMP'], 'guide_out.png')
if os.path.exists(temp_png):
    os.remove(temp_png)

chrome_path = r'C:\Program Files\Google\Chrome\Application\chrome.exe'
html_path = r'D:\IPS_app\IPS_app\masar_testflight_guide.html'

cmd = [
    chrome_path,
    '--headless=new',
    '--disable-gpu',
    '--hide-scrollbars',
    '--window-size=1200,1830',
    f'--screenshot={temp_png}',
    html_path
]

res = subprocess.run(cmd, capture_output=True, text=True)
if os.path.exists(temp_png):
    target_png = 'd:\\IPS_app\\IPS_app\\masar_testflight_guide.png'
    shutil.copy(temp_png, target_png)
    # Also copy to web_download
    shutil.copy(temp_png, 'd:\\IPS_app\\IPS_app\\web_download\\masar_testflight_guide.png')
    print('SUCCESS! Wrote masar_testflight_guide.png with size:', os.path.getsize(target_png))
else:
    print('Failed to generate png.')
