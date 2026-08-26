"""Self-contained HTML progress report.

One file, no CDN, no build step. Open it, screenshot it, post it, attach it to
an application. This is the artifact that answers "how do we know it works".
"""

import json
from pathlib import Path

# validated dark categorical steps, fixed order (never cycled)
SERIES = ["#3987e5", "#d95926", "#199e70", "#c98500", "#d55181",
          "#008300", "#9085e9", "#e66767"]

TEMPLATE = r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>__TITLE__</title>
<style>
  :root{
    --plane:#0d0d0d; --surface:#101014; --ink:#fff; --ink-2:#c3c2b7; --muted:#898781;
    --grid:#2c2c2a; --axis:#383835; --ring:rgba(255,255,255,.10); --good:#0ca30c;
  }
  *{box-sizing:border-box}
  body{margin:0;background:var(--plane);color:var(--ink);
       font:15px/1.5 system-ui,-apple-system,"Segoe UI",sans-serif;
       padding:40px 24px 64px}
  .wrap{max-width:1080px;margin:0 auto}
  h1{font-size:26px;margin:0 0 4px;letter-spacing:-.01em}
  .sub{color:var(--muted);font-size:14px;margin:0 0 32px}
  .tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px;margin-bottom:32px}
  .tile{background:var(--surface);border:1px solid var(--ring);border-radius:10px;padding:16px 18px}
  .tile .k{color:var(--muted);font-size:12px;text-transform:uppercase;letter-spacing:.06em}
  .tile .v{font-size:30px;margin-top:6px;letter-spacing:-.02em}
  .tile .d{font-size:13px;color:var(--ink-2);margin-top:2px}
  .tile .d.up{color:var(--good)}
  .card{background:var(--surface);border:1px solid var(--ring);border-radius:10px;
        padding:20px 22px 12px;margin-bottom:20px;position:relative}
  .card h2{font-size:15px;font-weight:600;margin:0 0 2px}
  .card .cap{color:var(--muted);font-size:12.5px;margin:0 0 14px}
  .legend{display:flex;flex-wrap:wrap;gap:16px;margin:0 0 12px;font-size:13px;color:var(--ink-2)}
  .legend i{width:10px;height:10px;border-radius:3px;display:inline-block;margin-right:7px;vertical-align:-1px}
  svg{display:block;width:100%;height:auto;overflow:visible}
  .gl{stroke:var(--grid);stroke-width:1}
  .ax{stroke:var(--axis);stroke-width:1}
  .tk{fill:var(--muted);font-size:11px;font-variant-numeric:tabular-nums}
  .dl{font-size:11.5px;fill:var(--ink-2)}
  .tip{position:absolute;pointer-events:none;opacity:0;transition:opacity .09s;
       background:#1a1a19;border:1px solid var(--ring);border-radius:8px;padding:9px 11px;
       font-size:12.5px;white-space:nowrap;box-shadow:0 6px 20px rgba(0,0,0,.5);z-index:5}
  .tip b{font-weight:600}
  .tip .r{display:flex;align-items:center;gap:7px;margin-top:4px;color:var(--ink-2)}
  .tip .r i{width:8px;height:8px;border-radius:2px;display:inline-block}
  .tip .r span{margin-left:auto;font-variant-numeric:tabular-nums;color:var(--ink)}
  details{margin-top:28px}
  summary{cursor:pointer;color:var(--ink-2);font-size:13.5px;padding:6px 0}
  table{border-collapse:collapse;width:100%;margin-top:10px;font-size:13px}
  th,td{text-align:left;padding:7px 10px;border-bottom:1px solid var(--grid);
        font-variant-numeric:tabular-nums}
  th{color:var(--muted);font-weight:500;font-size:11.5px;text-transform:uppercase;letter-spacing:.05em}
  .note{color:var(--muted);font-size:12.5px;margin-top:28px;line-height:1.6}
  h3.sec{font-size:12px;text-transform:uppercase;letter-spacing:.08em;color:var(--muted);
         margin:38px 0 14px;padding-bottom:8px;border-bottom:1px solid var(--grid)}
  .corr{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:12px;margin-bottom:20px}
  .corr .tile .v{font-size:24px}
  .corr .tile .n{color:var(--muted);font-size:11.5px;margin-top:6px}
</style></head><body><div class="wrap">
<h1>__TITLE__</h1>
<p class="sub">__SUB__</p>
<div class="tiles">__TILES__</div>
__CHARTS__
<details><summary>Table view — every session</summary>__TABLE__</details>
<p class="note">__NOTE__</p>
</div>
<script>
const CHARTS = __CHARTJSON__;
const W=980,H=300,M={t:16,r:96,b:34,l:52};
function draw(c){
  const el=document.getElementById(c.id), tip=document.getElementById(c.id+'-tip');
  const xs=c.x.length, iw=W-M.l-M.r, ih=H-M.t-M.b;
  const all=c.series.flatMap(s=>s.v.filter(v=>v!==null));
  let lo=Math.min(...all), hi=Math.max(...all); const pad=(hi-lo||1)*.18; lo-=pad; hi+=pad;
  if(c.zero) lo=Math.min(0,lo);
  const X=i=>M.l+(xs<2?iw/2:i*iw/(xs-1)), Y=v=>M.t+ih-(v-lo)/(hi-lo)*ih;
  const ticks=4, tv=[...Array(ticks+1)].map((_,i)=>lo+(hi-lo)*i/ticks);
  let s='';
  tv.forEach(v=>{s+=`<line class="gl" x1="${M.l}" x2="${M.l+iw}" y1="${Y(v).toFixed(1)}" y2="${Y(v).toFixed(1)}"/>`
    +`<text class="tk" x="${M.l-10}" y="${(Y(v)+4).toFixed(1)}" text-anchor="end">${v.toFixed(0)}</text>`;});
  s+=`<line class="ax" x1="${M.l}" x2="${M.l+iw}" y1="${M.t+ih}" y2="${M.t+ih}"/>`;
  c.x.forEach((lab,i)=>{ if(xs>8 && i%Math.ceil(xs/8)) return;
    s+=`<text class="tk" x="${X(i)}" y="${M.t+ih+20}" text-anchor="middle">${lab}</text>`;});
  const labels=[];
  c.series.forEach(se=>{
    const pts=se.v.map((v,i)=>v===null?null:[X(i),Y(v)]).filter(Boolean);
    if(!pts.length) return;
    s+=`<polyline fill="none" stroke="${se.c}" stroke-width="2" stroke-linejoin="round"
        stroke-linecap="round" points="${pts.map(p=>p[0].toFixed(1)+','+p[1].toFixed(1)).join(' ')}"/>`;
    pts.forEach(p=>{s+=`<circle cx="${p[0].toFixed(1)}" cy="${p[1].toFixed(1)}" r="4.5" fill="${se.c}"
        stroke="var(--surface)" stroke-width="2"/>`;});
    const last=pts[pts.length-1];
    labels.push({x:last[0]+12,y:last[1]+4,n:se.n});
  });
  if(c.series.length<=4 && labels.length){        // de-overlap the direct labels
    labels.sort((a,b)=>a.y-b.y);
    for(let i=1;i<labels.length;i++)
      if(labels[i].y-labels[i-1].y<15) labels[i].y=labels[i-1].y+15;
    labels.forEach(l=>{s+=`<text class="dl" x="${l.x.toFixed(1)}" y="${l.y.toFixed(1)}">${l.n}</text>`;});
  }
  s+=`<line id="${c.id}-cross" class="ax" y1="${M.t}" y2="${M.t+ih}" opacity="0"/>`;
  el.innerHTML=s;
  el.closest('.card').addEventListener('mousemove',e=>{
    const r=el.getBoundingClientRect(), px=(e.clientX-r.left)/r.width*W;
    if(px<M.l-14||px>M.l+iw+14){tip.style.opacity=0;document.getElementById(c.id+'-cross').setAttribute('opacity',0);return;}
    const i=Math.max(0,Math.min(xs-1,Math.round((px-M.l)/(xs<2?1:iw/(xs-1)))));
    const cx=X(i), cr=document.getElementById(c.id+'-cross');
    cr.setAttribute('x1',cx);cr.setAttribute('x2',cx);cr.setAttribute('opacity',.85);
    let h=`<b>${c.x[i]}</b>`;
    c.series.forEach(se=>{ if(se.v[i]===null) return;
      h+=`<div class="r"><i style="background:${se.c}"></i>${se.n}<span>${se.v[i].toFixed(1)}${c.unit}</span></div>`;});
    tip.innerHTML=h; tip.style.opacity=1;
    const cardR=el.closest('.card').getBoundingClientRect();
    tip.style.left=Math.min(cardR.width-tip.offsetWidth-12,Math.max(8,e.clientX-cardR.left+14))+'px';
    tip.style.top=(e.clientY-cardR.top-10)+'px';
  });
  el.closest('.card').addEventListener('mouseleave',()=>{tip.style.opacity=0;
    document.getElementById(c.id+'-cross').setAttribute('opacity',0);});
}
CHARTS.forEach(draw);
</script></body></html>"""


def _tile(k, v, d="", up=False):
    dd = f'<div class="d{" up" if up else ""}">{d}</div>' if d else ""
    return f'<div class="tile"><div class="k">{k}</div><div class="v">{v}</div>{dd}</div>'


def _corr_tile(label, r, n, direction_ok):
    if r is None:
        return (f'<div class="tile"><div class="k">{label}</div>'
                f'<div class="v">—</div><div class="n">needs 3+ sessions (n={n})</div></div>')
    strength = "strong" if abs(r) >= .7 else "moderate" if abs(r) >= .4 else "weak"
    cls = ' class="d up"' if (direction_ok and abs(r) >= .4) else ' class="d"'
    verdict = "moves the right way" if direction_ok else "moves against"
    return (f'<div class="tile"><div class="k">{label}</div>'
            f'<div class="v">r = {r:+.2f}</div>'
            f'<div{cls}>{strength}, {verdict}</div>'
            f'<div class="n">n = {n} sessions · correlation, not proof of cause</div></div>')


def _chart_card(cid, title, caption, series):
    leg = "".join(
        f'<span><i style="background:{s["c"]}"></i>{s["n"]}</span>' for s in series
    )
    return (f'<div class="card"><h2>{title}</h2><p class="cap">{caption}</p>'
            f'<div class="legend">{leg}</div>'
            f'<svg id="{cid}" viewBox="0 0 980 300" role="img"></svg>'
            f'<div class="tip" id="{cid}-tip"></div></div>')


def build(sessions, out="progress_report.html", title="XIV — movement progress"):
    if not sessions:
        raise SystemExit("No sessions logged yet.")

    dates = sorted({s["date"] for s in sessions})
    acts = sorted({s["activity"] for s in sessions})
    colours = {a: SERIES[i % len(SERIES)] for i, a in enumerate(acts)}

    def series_for(metric):
        out_s = []
        for a in acts:
            by_date = {s["date"]: s.get(metric) for s in sessions if s["activity"] == a}
            out_s.append({"n": a, "c": colours[a],
                          "v": [by_date.get(d) for d in dates]})
        return out_s

    sep = series_for("peak_separation")
    asym = series_for("elbow_asymmetry")

    flat = [v for s in sep for v in s["v"] if v is not None]
    first_by_act, last_by_act = {}, {}
    for s in sessions:
        if s.get("peak_separation") is None:
            continue
        first_by_act.setdefault(s["activity"], s["peak_separation"])
        last_by_act[s["activity"]] = s["peak_separation"]
    deltas = [last_by_act[a] - first_by_act[a] for a in last_by_act]
    avg_delta = sum(deltas) / len(deltas) if deltas else 0

    tiles = (
        _tile("Sessions", len(sessions), f"{len(dates)} days · {len(acts)} activities")
        + _tile("Peak separation", f"{max(flat):.0f}°" if flat else "—", "best recorded")
        + _tile("Change since first", f"{avg_delta:+.1f}°",
                "mean across activities", up=avg_delta > 0)
        + _tile("Frames measured", f"{sum(s.get('frames', 0) for s in sessions):,}",
                "every one timestamped")
    )

    # ---------- results layer: outcomes, and whether form tracks them ----------
    from .core.progress import pearson, better_direction

    outcome_keys = []
    for sess in sessions:
        for k in (sess.get("outcomes") or {}):
            if k not in outcome_keys:
                outcome_keys.append(k)

    results_html, corr_html = "", ""
    if outcome_keys:
        cards, corr_tiles = [], []
        for oi, key in enumerate(outcome_keys):
            o_series = []
            for a in acts:
                by_date = {s["date"]: (s.get("outcomes") or {}).get(key)
                           for s in sessions if s["activity"] == a}
                vals = [by_date.get(d) for d in dates]
                if any(v is not None for v in vals):
                    o_series.append({"n": a, "c": colours[a], "v": vals})
            if not o_series:
                continue
            pretty = key.replace("_", " ")
            cards.append(_chart_card(
                f"r{oi}", pretty,
                "Result, not form. Same x-axis as the charts above so you can read "
                "the two together — that is the whole argument.", o_series))

            # correlate form against this outcome, per activity
            for a in acts:
                form = [next((s.get("peak_separation") for s in sessions
                              if s["date"] == d and s["activity"] == a), None) for d in dates]
                out_vals = [next(((s.get("outcomes") or {}).get(key) for s in sessions
                                  if s["date"] == d and s["activity"] == a), None) for d in dates]
                r, n = pearson(form, out_vals)
                if n >= 3:
                    ok = (r is not None) and ((r * better_direction(key)) > 0)
                    corr_tiles.append(_corr_tile(f"{a} · separation vs {pretty}", r, n, ok))

        if cards:
            results_html = ('<h3 class="sec">Results — did the form change do anything</h3>'
                            + "".join(cards))
        if corr_tiles:
            corr_html = '<div class="corr">' + "".join(corr_tiles) + "</div>"

    charts_html = (
        '<h3 class="sec">Form — how the movement is executed</h3>'
        + _chart_card("c1", "Peak hip–shoulder separation",
                    "Degrees the shoulders rotate ahead of the hips. The primitive "
                    "shared by a golf swing, a serve and a pitch — more separation, "
                    "stored more elastically, generally means more transferred speed.",
                    sep)
        + _chart_card("c2", "Left/right elbow asymmetry",
                      "Median difference between the two sides in a session. Rising "
                      "asymmetry is the pattern that usually precedes a complaint. "
                      "Measurement only — it is not a diagnosis.", asym)
        + results_html + corr_html
    )

    rows = "".join(
        f"<tr><td>{s['date']}</td><td>{s['activity']}</td><td>{s.get('subject','')}</td>"
        f"<td>{s.get('peak_separation','—')}</td><td>{s.get('separation_range','—')}</td>"
        f"<td>{s.get('elbow_asymmetry','—')}</td><td>{s.get('frames','—')}</td>"
        f"<td>{', '.join(f'{k} {v}' for k, v in (s.get('outcomes') or {}).items()) or '—'}</td>"
        f"<td>{s.get('label','')}</td></tr>"
        for s in sessions
    )
    table = ("<table><thead><tr><th>Date</th><th>Activity</th><th>Subject</th>"
             "<th>Peak sep</th><th>Range</th><th>Elbow asym</th><th>Frames</th>"
             "<th>Results</th><th>Note</th></tr></thead><tbody>" + rows + "</tbody></table>")

    chart_specs = [
        {"id": "c1", "x": dates, "series": sep, "unit": "°", "zero": False},
        {"id": "c2", "x": dates, "series": asym, "unit": "°", "zero": True},
    ]
    for oi, key in enumerate(outcome_keys):
        os_series = []
        for a in acts:
            by_date = {s["date"]: (s.get("outcomes") or {}).get(key)
                       for s in sessions if s["activity"] == a}
            vals = [by_date.get(d) for d in dates]
            if any(v is not None for v in vals):
                os_series.append({"n": a, "c": colours[a], "v": vals})
        if os_series:
            chart_specs.append({"id": f"r{oi}", "x": dates, "series": os_series,
                                "unit": "", "zero": False})
    chart_json = json.dumps(chart_specs)

    html = (TEMPLATE
            .replace("__TITLE__", title)
            .replace("__SUB__", f"{len(sessions)} sessions · {dates[0]} to {dates[-1]}"
                                f" · measured from video, not self-reported")
            .replace("__TILES__", tiles)
            .replace("__CHARTS__", charts_html)
            .replace("__TABLE__", table)
            .replace("__NOTE__", "Form numbers come from pose estimation on video, compared "
                                 "against the subject's own baseline rather than a template. "
                                 "Results are measured separately — times, counts, and "
                                 "self-reported scores. Correlation between the two is reported "
                                 "with its sample size and is not a claim about cause. Depth is "
                                 "not used; all metrics are 2D from a consistent camera angle.")
            .replace("__CHARTJSON__", chart_json))

    Path(out).write_text(html)
    return out
