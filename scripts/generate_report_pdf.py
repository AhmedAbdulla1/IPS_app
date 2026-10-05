import os
import subprocess
import csv

CSV_DATA = """node_id,level_id,name_ar,name_en,esp32_uuid,x,y
625,L6,لجنة الطاقة والبيئة,لجنة الطاقة والبيئة,0dd9409f-ea4c-5916-885e-30eed2db3cef,43,52
633,L6,لجنة الإعلام,لجنة الأعلام,0dd9409f-ea4c-5916-885e-30eed2db3cef,51,39
238,L2,تقاطع,Intersection,0de49f96-cdd6-a216-cb24-a3d18e9a5312,77,48
241,L2,ممر,Corridor,0de49f96-cdd6-a216-cb24-a3d18e9a5312,89,42
216,L2,تقاطع,Intersection,203de236-339c-2229-2213-db6b21ca36ac,81,102
220,L2,ممر,Corridor,203de236-339c-2229-2213-db6b21ca36ac,67,89
347,L3,لجنة الشئون الصحية,Health Affairs Committee,234755a5-23bc-306a-db39-d5a8ba0fadde,139,39
359,L3,تقاطع,Intersection,234755a5-23bc-306a-db39-d5a8ba0fadde,122,58
758,L7,أسانسير,Elevator,57a674ca-619a-b49f-eac7-2d7021623195,137,49
759,L7,تقاطع,Intersection,57a674ca-619a-b49f-eac7-2d7021623195,122,58
513,L5,أسانسير,Elevator,adbe242e-6a2e-637e-db8d-e5f52cc223f2,95,122
515,L5,تقاطع,Intersection,adbe242e-6a2e-637e-db8d-e5f52cc223f2,95,104
659,L6,تقاطع,Intersection,ae82024e-dea9-78e3-9107-e43b49f65314,122,58
744,L7,تقاطع,Intersection,ae82024e-dea9-78e3-9107-e43b49f65314,113,48
322,L3,تقاطع,Intersection,dc350f7b-c4bf-3f16-f2dd-727faa512451,63,71
323,L3,قاعة استماع 9,Hearing Hall (9),dc350f7b-c4bf-3f16-f2dd-727faa512451,55,64"""

def main():
    rows = list(csv.DictReader(CSV_DATA.strip().splitlines()))
    
    # Group by UUID
    groups = {}
    for r in rows:
        uid = r['esp32_uuid']
        groups.setdefault(uid, []).append(r)
        
    table_rows_html = []
    group_idx = 1
    
    for uid, items in groups.items():
        levels = set(it['level_id'] for it in items)
        is_cross_floor = len(levels) > 1
        
        table_rows_html.append(f"""
        <tr class="group-header">
            <td colspan="7">
                <div class="group-header-content">
                    <span class="group-title">المجموعة {group_idx}</span>
                    <span class="uuid-badge">{uid}</span>
                    <span class="count-badge">{len(items)} نقاط متطابقة</span>
                    {'<span class="cross-badge">⚠️ تعارض بين أدوار مختلفة (' + ', '.join(levels) + ')</span>' if is_cross_floor else '<span class="same-badge">نفس الدور (' + list(levels)[0] + ')</span>'}
                </div>
            </td>
        </tr>
        """)
        
        for item in items:
            note_class = "note-cross" if is_cross_floor else "note-same"
            note_text = f"تعارض مع دور {', '.join(levels - {item['level_id']})}" if is_cross_floor else "تعارض موضعي بنفس الدور"
            
            table_rows_html.append(f"""
            <tr class="data-row">
                <td class="node-id">#{item['node_id']}</td>
                <td><span class="level-pill">{item['level_id']}</span></td>
                <td class="name-ar">{item['name_ar']}</td>
                <td class="name-en">{item['name_en']}</td>
                <td class="coord">({item['x']}, {item['y']})</td>
                <td><span class="{note_class}">{note_text}</span></td>
            </tr>
            """)
        group_idx += 1

    html_content = f"""<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<title>تقرير النقاط المتكرر فيها معرّفات ESP32</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700;800;900&display=swap" rel="stylesheet">
<style>
  @page {{
    size: A4 portrait;
    margin: 8mm 10mm;
  }}
  
  * {{
    box-sizing: border-box;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }}
  
  body {{
    font-family: 'Cairo', 'Segoe UI', Tahoma, Arial, sans-serif;
    background-color: #ffffff;
    color: #0f172a;
    margin: 0;
    padding: 0;
    direction: rtl;
    text-align: right;
    line-height: 1.35;
  }}

  .header {{
    background: linear-gradient(135deg, #1e3a8a 0%, #0f172a 100%);
    color: #ffffff;
    padding: 14px 18px;
    border-radius: 8px;
    margin-bottom: 10px;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }}

  .header-info h1 {{
    margin: 0 0 2px 0;
    font-size: 17px;
    font-weight: 800;
  }}

  .header-info p {{
    margin: 0;
    font-size: 11px;
    color: #cbd5e1;
  }}

  .status-badge {{
    background: rgba(239, 68, 68, 0.25);
    border: 1px solid #ef4444;
    color: #fee2e2;
    padding: 4px 12px;
    border-radius: 16px;
    font-size: 11px;
    font-weight: 700;
  }}

  .stats-container {{
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 8px;
    margin-bottom: 12px;
  }}

  .stat-card {{
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    border-radius: 6px;
    padding: 6px 12px;
  }}

  .stat-card .label {{
    font-size: 10px;
    color: #64748b;
    font-weight: 600;
    margin-bottom: 1px;
  }}

  .stat-card .value {{
    font-size: 15px;
    font-weight: 800;
    color: #1e293b;
  }}

  .stat-card.danger .value {{
    color: #dc2626;
  }}

  table {{
    width: 100%;
    border-collapse: collapse;
    font-size: 10.5px;
  }}

  th {{
    background: #f1f5f9;
    color: #334155;
    font-weight: 700;
    padding: 6px 8px;
    border: 1px solid #cbd5e1;
    text-align: right;
  }}

  .group-header td {{
    background: #f1f5f9;
    border: 1px solid #cbd5e1;
    border-top: 1.5px solid #64748b;
    padding: 5px 8px;
  }}

  .group-header-content {{
    display: flex;
    align-items: center;
    gap: 8px;
  }}

  .group-title {{
    font-weight: 800;
    color: #1e3a8a;
    font-size: 11px;
  }}

  .uuid-badge {{
    font-family: 'Consolas', 'Courier New', monospace;
    direction: ltr;
    background: #e2e8f0;
    padding: 1px 6px;
    border-radius: 4px;
    font-size: 10px;
    font-weight: 600;
    color: #0f172a;
  }}

  .count-badge {{
    background: #fee2e2;
    color: #991b1b;
    font-size: 9.5px;
    font-weight: 700;
    padding: 1px 6px;
    border-radius: 10px;
  }}

  .cross-badge {{
    background: #ffedd5;
    color: #c2410c;
    font-size: 9.5px;
    font-weight: 700;
    padding: 1px 6px;
    border-radius: 10px;
  }}

  .same-badge {{
    background: #f0fdf4;
    color: #166534;
    font-size: 9.5px;
    font-weight: 600;
    padding: 1px 6px;
    border-radius: 10px;
  }}

  .data-row td {{
    padding: 4.5px 8px;
    border: 1px solid #e2e8f0;
    background: #ffffff;
  }}

  .node-id {{
    font-weight: 800;
    color: #0f172a;
    font-family: 'Consolas', monospace;
  }}

  .level-pill {{
    display: inline-block;
    padding: 1px 6px;
    background: #e0f2fe;
    color: #0369a1;
    border-radius: 4px;
    font-weight: 700;
    font-size: 10px;
  }}

  .name-ar {{
    font-weight: 700;
    color: #1e293b;
  }}

  .name-en {{
    color: #64748b;
    direction: ltr;
    text-align: right;
  }}

  .coord {{
    direction: ltr;
    font-family: 'Consolas', monospace;
    color: #475569;
    font-size: 10px;
  }}

  .note-cross {{
    display: inline-block;
    background: #fff1f2;
    color: #be123c;
    padding: 1px 6px;
    border-radius: 4px;
    font-weight: 700;
    font-size: 9.5px;
    border: 1px solid #fecdd3;
  }}

  .note-same {{
    display: inline-block;
    background: #f8fafc;
    color: #64748b;
    padding: 1px 6px;
    border-radius: 4px;
    font-weight: 600;
    font-size: 9.5px;
  }}

  .footer {{
    margin-top: 10px;
    display: flex;
    justify-content: space-between;
    font-size: 9.5px;
    color: #94a3b8;
    border-top: 1px solid #e2e8f0;
    padding-top: 6px;
  }}
</style>
</head>
<body>

  <div class="header">
    <div class="header-info">
      <h1>تقرير فحص تكرار معرّفات الـ ESP32 iBeacon</h1>
      <p>مشروع نظام الملاحة وتحديد المواقع الداخلي (IPS) — جدول العقد (Nodes Table)</p>
    </div>
    <div class="status-badge">⚠️ 8 حالات تعارض</div>
  </div>

  <div class="stats-container">
    <div class="stat-card danger">
      <div class="label">معرّفات UUID المكررة</div>
      <div class="value">8 معرّفات</div>
    </div>
    <div class="stat-card danger">
      <div class="label">إجمالي النقاط المتأثرة</div>
      <div class="value">16 نقطة</div>
    </div>
    <div class="stat-card">
      <div class="label">الأدوار المتأثرة</div>
      <div class="value">L2, L3, L5, L6, L7</div>
    </div>
    <div class="stat-card">
      <div class="label">تعارض بين أدوار مختلفة</div>
      <div class="value" style="color: #ea580c;">مجموعة واحدة (L6 / L7)</div>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th style="width: 75px;">رقم النقطة</th>
        <th style="width: 60px;">الدور</th>
        <th style="width: 25%;">الاسم بالعربي</th>
        <th style="width: 25%;">الاسم بالإنجليزي</th>
        <th style="width: 80px;">الإحداثيات</th>
        <th>طبيعة التعارض</th>
      </tr>
    </thead>
    <tbody>
      {''.join(table_rows_html)}
    </tbody>
  </table>

  <div class="footer">
    <div>نظام تحديد المواقع الداخلي (IPS) — استخراج من Supabase Database</div>
    <div>تاريخ الفحص: 2026-10-01</div>
  </div>

</body>
</html>
"""

    html_path = os.path.abspath("duplicated_nodes.html")
    pdf_path = os.path.abspath("duplicated_nodes.pdf")

    with open(html_path, "w", encoding="utf-8") as f:
        f.write(html_content)
    print(f"HTML saved at: {html_path}")

    # Convert to PDF using Edge or Chrome
    edge_paths = [
        r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Google\Chrome\Application\chrome.exe"
    ]
    browser_bin = None
    for p in edge_paths:
        if os.path.exists(p):
            browser_bin = p
            break
            
    if not browser_bin:
        print("No chromium browser found")
        return

    cmd = [
        browser_bin,
        "--headless",
        "--disable-gpu",
        "--no-pdf-header-footer",
        f"--print-to-pdf={pdf_path}",
        html_path
    ]
    print(f"Running browser to create PDF via {browser_bin}...")
    res = subprocess.run(cmd, capture_output=True, text=True)
    if os.path.exists(pdf_path) and os.path.getsize(pdf_path) > 0:
        print(f"SUCCESS: PDF created at: {pdf_path} (Size: {os.path.getsize(pdf_path)} bytes)")
    else:
        print(f"FAILED: {res.stderr}")

if __name__ == "__main__":
    main()
