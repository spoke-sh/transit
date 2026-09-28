"""Reproduce the synthetic D1 and Atlas D10 vector review plates.

Run from any directory with Python 3. Standard library only. These are design
compositions, not runtime renderers, calibrated plots or conformance fixtures.
Existing Atlas PNGs and D1-D9 reviews are never rewritten.
"""
from pathlib import Path
from html import escape
import json
import math
import re

HERE = Path(__file__).resolve().parent
ATLAS = HERE.parent / "board-atlas"


class Plate:
    def __init__(self, title, subtitle, sidebar=False, active="Atlas"):
        self.parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="960" viewBox="0 0 1440 960" role="img" aria-labelledby="title desc"><title id="title">{escape(title)}</title><desc id="desc">{escape(subtitle)}. Synthetic monochrome review; not implemented UI.</desc>',
            '<defs><pattern id="gap" width="10" height="10" patternUnits="userSpaceOnUse"><path d="M-2 2L2 -2M0 10L10 0M8 12L12 8" stroke="black" stroke-width="0.7"/></pattern></defs>']
        self.rect(0, 0, 1440, 960)
        self.text(24, 36, "Transit", 22, True)
        self.rect(420, 10, 600, 36)
        self.text(440, 34, "Search Transit…", 15)
        self.text(948, 33, "⌘ K", 13)
        self.rect(1178, 10, 230, 36)
        self.text(1194, 34, "Storefront  ▾", 15, True)
        self.line(0, 56, 1440, 56)
        if sidebar:
            self.line(208, 56, 208, 918)
            self.text(28, 94, "Workspace / Operations", 12, True)
            for i, name in enumerate(["Atlas", "Explore", "Connections", "Sources", "Sinks", "Activity"]):
                self.text(32, 150+i*42, name, 15, name == active)
                if name == active:
                    self.line(16, 134+i*42, 16, 155+i*42, 3)
        self.left = 240 if sidebar else 32
        self.text(self.left, 108, title, 24, True)
        self.text(self.left, 140, subtitle, 14)
        self.line(self.left, 168, 1408, 168)
        self.line(0, 918, 1440, 918)
        self.text(24, 944, "DESIGN STUDY  ·  Synthetic evidence  ·  Schematic geometry  ·  No capacity or implementation claim", 12)

    def raw(self, s):
        self.parts.append(s)

    def text(self, x, y, value, size=14, bold=False, mono=False, anchor="start", fill="black"):
        self.raw(f'<text x="{x}" y="{y}" font-family="{("monospace" if mono else "sans-serif")}" font-size="{size}" font-weight="{700 if bold else 400}" text-anchor="{anchor}" fill="{fill}">{escape(str(value))}</text>')

    def rect(self, x, y, w, h, fill="white", width=1, dash=False):
        self.raw(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" stroke="black" stroke-width="{width}"'+(' stroke-dasharray="6 5"' if dash else '')+'/>')

    def line(self, x1, y1, x2, y2, width=1, dash=False):
        self.raw(f'<path d="M{x1} {y1}L{x2} {y2}" fill="none" stroke="black" stroke-width="{width}"'+(' stroke-dasharray="6 5"' if dash else '')+'/>')

    def path(self, d, fill="none", width=1, dash=False):
        self.raw(f'<path d="{d}" fill="{fill}" stroke="black" stroke-width="{width}"'+(' stroke-dasharray="6 5"' if dash else '')+'/>')

    def ellipse(self, x, y, rx, ry, fill="white", width=1):
        self.raw(f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="black" stroke-width="{width}"/>')

    def button(self, x, y, label, primary=False, width=None, unavailable=False):
        w = width or len(label)*8+28
        self.rect(x, y, w, 34, "black" if primary else "white", dash=unavailable)
        self.text(x+14, y+23, label, 14, primary, fill="white" if primary else "black")

    def note(self, x, y, lines, title=None):
        if title:
            self.text(x, y, title, 17, True)
            y += 30
        for i, s in enumerate(lines):
            self.text(x, y+i*25, s, 14)

    def table(self, x, y, widths, headers, rows, row_h=42):
        total = sum(widths)
        self.line(x, y, x+total, y, 2)
        for ri, row in enumerate([headers]+rows):
            xx = x
            for value, width in zip(row, widths):
                self.text(xx+10, y+ri*row_h+27, value, 14, ri == 0)
                xx += width
            self.line(x, y+(ri+1)*row_h, x+total, y+(ri+1)*row_h)

    def arrow(self, x1, y1, x2, y2, label="", dash=False):
        self.line(x1, y1, x2, y2, dash=dash)
        a=math.atan2(y2-y1,x2-x1)
        for delta in [-0.55,0.55]:
            self.line(x2, y2, x2-9*math.cos(a+delta), y2-9*math.sin(a+delta))
        if label:
            self.text((x1+x2)/2, (y1+y2)/2-12, label, 12, anchor="middle")

    def save(self, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("\n".join(self.parts)+"\n</svg>\n")


def process(p, x, y, inbox, outbox=0, scale=1, label="", age=None, flat=False, selected=False):
    w=58*scale
    h=(12+math.sqrt(inbox)*7)*scale if inbox and not flat else 0
    p.ellipse(x,y,w,20*scale, width=2 if selected else 1)
    if not flat and inbox:
        for f in [0.3,0.6,1]:
            rx=w*(1-f*.5)
            p.ellipse(x,y-h*f,rx,rx*.28)
        p.path(f'M{x-w} {y} Q{x-w*.85} {y-h*.8} {x-w*.5} {y-h}')
        p.path(f'M{x+w} {y} Q{x+w*.85} {y-h*.8} {x+w*.5} {y-h}')
    if outbox and not flat:
        top=y-h
        depth=(10+math.sqrt(outbox)*6)*scale
        p.ellipse(x,top,20*scale,7*scale)
        p.path(f'M{x-20*scale} {top}L{x-13*scale} {top+depth} Q{x} {top+depth+6*scale} {x+13*scale} {top+depth}L{x+20*scale} {top}')
        if age:
            for dx in [-9,0,9]:
                p.line(x+dx*scale,top+5*scale,x+dx*.6*scale,top+depth-2*scale,.7)
    if selected:
        p.rect(x-w-9,y-24*scale,w*2+18,52*scale,fill="none",width=2)
    if label:
        p.text(x,y+(62 if outbox and not inbox and not flat else 43)*scale,label,14,selected,anchor="middle")


def cube(p,x,y,w,h,d=22,dash=False):
    p.path(f'M{x} {y}L{x+w} {y}L{x+w+d} {y-d}L{x+d} {y-d}Z',"white",dash=dash)
    p.path(f'M{x} {y}L{x} {y-h}L{x+w} {y-h}L{x+w} {y}Z',"white",dash=dash)
    p.path(f'M{x+w} {y}L{x+w+d} {y-d}L{x+w+d} {y-h-d}L{x+w} {y-h}Z',"white",dash=dash)
    p.path(f'M{x} {y-h}L{x+d} {y-h-d}L{x+w+d} {y-h-d}L{x+w} {y-h}Z',"white",dash=dash)


def resource(p,x,y,kind,w=110,h=110,label="",flat=False,selected=False):
    if selected:
        p.rect(x-18,y-8,w+64,42,fill="none",width=2)
    if flat:
        p.rect(x,y-12,w,24)
        p.text(x+w/2,y+5,kind.upper(),12,anchor="middle")
    elif kind=="table":
        cube(p,x,y,w,h)
        for k in range(1,4):
            p.line(x,y-h*k/4,x+w,y-h*k/4)
        for k in range(1,4):
            p.line(x+w*k/4,y-h,x+w*k/4,y)
    elif kind=="kv":
        cube(p,x+w*.52,y,w*.48,h*.64)
        cube(p,x,y,w*.46,h)
        for yy in [.33,.67]:
            p.line(x,y-h*yy,x+w*.46,y-h*yy)
    elif kind=="document":
        cube(p,x,y,w,h*.33)
        cube(p,x+12,y-h*.33,w*.72,h*.33)
        cube(p,x+24,y-h*.66,w*.46,h*.34)
    else:
        cube(p,x,y,w,h)
    if label:
        p.text(x+w/2+10,y+58,label,14,selected,anchor="middle")


SEED=json.loads((ATLAS/'scale-fixture.json').read_text())
D4=json.loads((ATLAS/'d4-fixture.json').read_text())
D5=json.loads((ATLAS/'d5-fixture.json').read_text())
D6=json.loads((ATLAS/'d6-fixture.json').read_text())
D7=json.loads((ATLAS/'d7-fixture.json').read_text())


def inspector(p,x=1096,y=230,resource_info=False):
    p.rect(x,y,290,322,width=2)
    p.text(x+20,y+34,"R17 · Table resource" if resource_info else "Process 04 · PID 4",18,True)
    lines=(["Current values   32 MiB","Writer   PID 41","Lifetime   Independent","3 disclosed associations","T1   24 MiB   /   T2   6 MiB","Framework   2 MiB"] if resource_info else ["Inbox pending   36","Generation   3","State revision   18","Observation   240","Policy revision   7","Retained from   160"])
    p.note(x+20,y+70,lines)
    p.button(x+20,y+260,"Open resource" if resource_info else "Open process")


def eight_processes(p,outboxes=False,flatten=False,gap=False,relief=1):
    positions=[(365,355),(605,315),(845,355),(605,535),(845,535),(845,720),(605,745),(365,625)]
    for d,(x,y) in zip(SEED['seed'],positions):
        if gap and d['pid'] in (3,5,6):
            continue
        process(p,x,y,d['inbox'],d['outbox'] if outboxes else 0,scale=relief,label=f"P{d['pid']:02d}   {d['inbox']} in"+(f" / {d['outbox']} out" if outboxes else ""),age=d['age'] if outboxes else None,flat=flatten,selected=d['pid']==4)
        if outboxes and d['outbox']:
            age=f"{d['age']//60}m" if d['age']>=60 else f"{d['age']}s"
            p.text(x,y+(84 if not d['inbox'] else 66)*relief,f"Oldest {age}",12,anchor="middle")
    if gap:
        p.rect(780,250,235,555,"url(#gap)")
        p.rect(798,445,199,85)
        p.note(812,475,["Outside returned page","Coverage unknown"])


def draw_d1(p,fig):
    if fig in [1,2,6]:
        p.text(240,200,"Map   /   Browse",14,True)
        eight_processes(p,gap=fig==6,relief=.7 if fig==2 else 1)
        inspector(p)
        if fig==2:
            p.arrow(668,535,783,535,"delivery")
            p.rect(300,450,120,45)
            p.text(312,478,"Resource 12",14)
            p.line(415,480,554,527,dash=True)
            p.text(428,481,"association",12)
        if fig==6:
            p.note(1096,602,["Disconnected","Last observed counts","held at basis 240.","History gap: before 160","Known denial clears data."],"Observation interrupted")
        else:
            p.note(1096,606,["8 displayed processes","84 pending inputs","Height = inbox pending","Not a realm-wide total."],"Displayed page")
    elif fig==3:
        for i,(name,count) in enumerate([("P01",18),("P02",12),("P03",8),("P04",36),("P05",6),("P06",4),("P07",0),("P08",0)]):
            x=240+(i%4)*210; y=230+(i//4)*150
            p.rect(x,y,190,115,width=2 if name=="P04" else 1)
            p.text(x+16,y+32,name,17,True)
            p.text(x+16,y+68,f"Inbox {count}",16)
            p.text(x+16,y+95,"Observed · position 240",12)
        inspector(p)
        journey(p,260,675)
    elif fig==4:
        p.text(240,202,"Browse   /   Map",14,True)
        rows=[[f"Process {d['pid']:02d}",str(d['pid']),"Suspended" if d['pid']==3 else "Terminated" if d['pid']==8 else "Running",str(d['inbox'])] for d in SEED['seed']]
        p.table(240,230,[230,120,230,220],["Process","PID","Lifecycle","Inbox pending"],rows,52)
        p.rect(240,438,800,52,fill="none",width=2)
        inspector(p)
        p.button(240,770,"Show on map")
    elif fig==5:
        p.text(240,214,"Process 04  /  Inbox  /  Outbox  /  State  /  Journey",16,True)
        p.table(240,250,[360,300,508],["Mailbox accounting","Count","Meaning"],[["Admitted","120","Recorded inputs"],["Consumed","80","Committed input progress"],["Cancelled","4","Recorded terminal disposition"],["Pending","36","120 − 80 − 4"]])
        p.text(240,515,"Resource 12 · revision 9 · separately authorized",16)
        journey(p,260,635)
        p.note(240,796,["Retained from position 160 · observed at 240 · policy 7","Destination admission does not prove destination turn completion."])


def journey(p,x,y):
    for i,(head,sub) in enumerate([("Input 41","PID 4"),("Turn 18","Committed"),("Output 7","Recorded"),("Input 22","PID 5 · admitted")]):
        xx=x+i*205
        p.rect(xx,y,170,80)
        p.text(xx+14,y+30,head,16,True)
        p.text(xx+14,y+59,sub,13)
        if i<3:
            p.arrow(xx+170,y+40,xx+205,y+40)


def draw_d2(p,fig):
    if fig==7:
        eight_processes(p,outboxes=True)
        p.note(1096,242,["Inbox   36","Outbox awaiting delivery   12","Oldest pending output   18m","Age marks belong to well walls.","Selection uses a strong perimeter."],"P04 · two independent queues")
        p.line(1096,425,1386,425)
        p.note(1096,468,["Shoulder height → inbox count","Depth from shoulder → outbox","Wall marks + number → age","Empty outbox → no oldest age","Missing evidence → unavailable"],"Monochrome encoding")
        p.note(1096,693,["Displayed totals","Inbox 84   /   Outbox 44","Ages are synthetic.","No runtime timestamp proof."])
    elif fig==8:
        for i,(age,depth) in enumerate([("30 seconds",22),("6 minutes",65),("18 minutes",170)]):
            x=310+i*395
            p.text(x,230,age,22,True)
            p.line(x-25,525,x+310,525,dash=True)
            p.path(f'M{x-15} 525Q{x+10} 390 {x+65} 390L{x+110} 390L{x+130} {390+depth}L{x+170} {390+depth}L{x+190} 390L{x+220} 390Q{x+290} 390 {x+300} 525',width=2)
            p.text(x,585,"Inbox 36 · Outbox 12",17)
            p.text(x,620,"Depth = oldest output age",14)
        p.note(240,744,["Alternative layer: Outbox age. Not the selected count-depth encoding.","The inbox shoulder and both queue counts remain fixed.","Time does not drain queues; these are three hypothetical observations."])
    else:
        for i,label in enumerate(["Fabric","Approach","Flat inspection"]):
            x=335+i*395
            p.text(x,240,label,19,True)
            if i<2:
                process(p,x+110,450,36,12,scale=1.8 if i==0 else .7,age=1080)
                p.text(x,555,"Inbox 36 / Outbox 12",17)
                p.text(x,585,"Oldest 18m",15)
            else:
                p.rect(x-20,300,290,310)
                p.note(x,338,["Inbox   36","Outbox   12","Oldest   18m","Age groups","< 1m      3 outputs","1–10m    5 outputs","10–30m  4 outputs"])
        p.note(240,740,["Relief amplitude changes only presentation. Values and selected identity stay fixed.","At reading distance, exact queues and age coverage replace depth."])


def draw_d3(p,fig):
    index=fig-10; n=[100,1000,10000,100000][index]
    summary=SEED['summaries']['population'][index]
    p.text(240,204,f"{n:,} processes in synthetic scope · {'process' if index==0 else 'group summary'} marks",16,True)
    for i in range(100):
        x=285+(i%10)*73; y=280+(i//10)*49
        if index==0:
            d=SEED['seed'][i] if i<8 else {'inbox':(i+1)%5,'outbox':(i+1)%3}
            process(p,x,y,d['inbox'],d['outbox'],scale=.37)
        else:
            p.path(f'M{x-27} {y}L{x-13} {y-20}L{x+18} {y-20}L{x+30} {y}L{x+14} {y+18}L{x-14} {y+18}Z')
            p.ellipse(x,y-4,15,7)
            p.ellipse(x,y,7,4)
    for j in range(10):
        p.rect(251,252+j*49,733,48,fill="none",dash=True)
    p.note(1075,255,[f"Population   {n:,}",f"Inbox total   {summary['inbox']:,}",f"Outbox total   {summary['outbox']:,}",f"Each mark   {10**index:,} process"+("es" if index else ""),"Grouping   stable identity cells","Complete for synthetic scope"],"Disclosed summary")
    if index==3:
        p.rect(590,660,215,55,width=2)
        p.text(608,693,"PID 41773 · 47m",17,True)
        p.note(1075,545,["PID 41773","Inbox 0 · Outbox 1","Oldest pending 47m","Containing district E.02","Inbox 1,997 · Outbox 999"],"Oldest in displayed scope")
    else:
        p.note(1075,555,["One stable home per PID","Summary ≠ individual process","Browse exposes member pages.","Empty anchors remain visible."])
    p.note(240,829,["Layout groups are not security realms. Count geometry and age evidence stay separate.","Membership, query coverage and scene complexity need public bounded contracts."])


def draw_d4(p,fig):
    index=min(fig-1,3); scene=D4['scenes'][index]
    cells=scene['cells']; cols=[8,8,5,4][index]; rows=math.ceil(len(cells)/cols)
    cellw=1300/cols; cellh=500/rows
    p.text(32,204,f"{scene['totals']['processes']:,} processes · {len(cells)} primary groups · group geometry is schematic",16,True)
    for i,c in enumerate(cells):
        x=65+(i%cols)*cellw; y=285+(i//cols)*cellh
        w=cellw-24; h=cellh-40
        p.path(f'M{x} {y+h*.2}Q{x+w*.2} {y-h*.3} {x+w*.5} {y}Q{x+w*1.1} {y-h*.1} {x+w} {y+h*.7}Q{x+w*.7} {y+h*1.15} {x+w*.3} {y+h}Q{x-w*.1} {y+h*.8} {x} {y+h*.2}Z',width=2 if i==0 else 1)
        p.ellipse(x+w*.48,y+h*.45,w*.3,h*.34,fill="none")
        p.ellipse(x+w*.48,y+h*.48,w*.14,h*.19,fill="none")
        if (i<3 or index==3) and not (fig==5 and i==3):
            p.text(x+12,y+h+24,f"Group {c['id']}",12,i==0)
    if fig==5:
        p.rect(1020,248,366,240,width=2)
        p.note(1042,286,["Inbox 0 · Outbox 1","Oldest pending output 47m","Within Group A","Values complete for synthetic PID"],"PID 41773")
        p.button(1042,426,"Go to process")
    else:
        p.rect(62,230,248,34)
        p.text(77,253,"47m · oldest in first group",14,True)
    p.note(32,824,[f"Inbox total {scene['totals']['inbox']:,}   /   Outbox total {scene['totals']['outbox']:,}   ·   Separate compressed scales",
        "Parent, child and outlier counts are never added together. Fixed layout area does not encode population."])


def shared_scene(p,mode="resources",detail=False,portal=False):
    if detail:
        p.rect(300,260,665,400,width=2)
        p.text(324,296,"R17 · one backing resource",20,True)
        for x,w,name in [(328,320,"T1"),(682,250,"T2")]:
            p.rect(x,340,w,245)
            p.text(x+20,377,name,22,True)
            p.text(x+20,413,"Table keyspace",14)
        for x,pid in [(340,41),(620,52),(910,63)]:
            p.ellipse(x,746,24,24)
            p.text(x,751,str(pid),13,anchor="middle")
            p.line(x,720,620,661,dash=True)
        p.text(310,805,"Recorded associations · 3 disclosed · no grants or lifetime ownership",14)
    else:
        for x,y,pid in [(320,370,41),(660,310,52),(430,700,63)]:
            d=next(a for a in D6['processes'] if a['pid']==pid)
            process(p,x,y,d['pendingInbox'],d['pendingOutbox'],label=f"PID {pid}",age=d['oldestPendingOutputAgeSeconds'],flat=mode!='processes')
            p.line(x+20,y,714,510,dash=True)
            if mode=='processes':
                p.text(x,y+87,f"In {d['pendingInbox']} / Out {d['pendingOutbox']}",13,anchor="middle")
                if d['oldestPendingOutputAgeSeconds']:
                    p.text(x,y+107,f"Oldest {d['oldestPendingOutputAgeSeconds']//60}m · synthetic",12,anchor="middle")
        p.rect(632,524,209,54,fill="none",width=2)
        resource(p,650,535,"table",w=60,h=105,flat=mode!='resources')
        resource(p,742,535,"table",w=60,h=105,flat=mode!='resources')
        p.text(680,569,"T1",13,True,anchor="middle")
        p.text(772,569,"T2",13,True,anchor="middle")
        p.text(734,602,"R17 · one backing resource",14,True,anchor="middle")
        resource(p,895,365,"kv",w=85,h=80,label="R18 · KV",flat=mode!='resources')
        resource(p,887,700,"document",w=100,h=120,label="R19 · Document",flat=mode!='resources')
        p.text(515,613,"association",12)
    inspector(p,resource_info=True)
    if portal:
        p.button(1116,610,"Enter resource",True)
        p.text(1096,680,"Auto · Resources (proposed)",14,True)
    p.text(32 if p.left==32 else 240,869,"Relief flattened for reading" if detail else "Switching to Resources · no active height scale" if mode=='handoff' else "Processes · queue counts" if mode=='processes' else "Resources · current value bytes",15,True)


def draw_d5(p,fig):
    if fig==1:
        for i,kind in enumerate(["table","kv","document"]):
            x=160+i*440
            resource(p,x,570,kind,w=180,h=230,label=kind.upper())
            p.text(x+90,686,"32 MiB",22,True,anchor="middle")
        p.line(90,318,1350,318,dash=True)
        p.note(32,810,["One shared height reference. Structure changes the motif; kind does not determine size.","Facades, modules and terraces are not literal row/key/node counts."])
    elif fig==2:
        for i,r in enumerate(D5['neighborhood']['resources']):
            x=65+(i%8)*164; y=292+(i//8)*100
            h=8+math.log2(r['currentValueBytes']/1048576+1)*4
            resource(p,x,y,r['form'],w=67,h=h)
            p.text(x+44,y+23,f"R{r['id']}",13,anchor="middle")
        p.note(32,840,["48 unique resources · stable plots · height sketches current value bytes","Large KV and Document landmarks remain visible. No process-to-resource population ratio."])
    elif fig in [3,4]:
        scene=D5['scenes'][fig-3]
        count=scene['primaryGroups']; cols=6 if fig==3 else 4
        for i,cell in enumerate(scene['cells']):
            x=70+(i%cols)*(1280/cols); y=355+(i//cols)*118
            w=110 if cols==6 else 170
            h=12+math.log2(cell['currentValueBytes']/1048576+1)*3
            resource(p,x,y,"group",w=w,h=h)
            p.text(x+w/2+10,y+24,f"Group {cell['id']}",13,anchor="middle")
        p.text(32,205,f"{10000 if fig==3 else 1000000:,} resources · {count} disjoint group summaries",17,True)
        if fig==4:
            p.rect(40,230,247,40,width=2)
            p.text(54,256,"R3 · Document · 4 GiB",15,True)
        p.note(32,844,["Sum unique current-value bytes before compression. Parent and child masses never coexist as totals.","A group mass is not an invented population of small buildings. Scope and coverage remain explicit."])
    else:
        shared_scene(p)


def draw_d6(p,fig):
    shared_scene(p,mode=['processes','handoff','resources','resources'][fig-1],detail=fig==4)


def sample_table(p,x,y,width=960):
    rows=[[r['sample_id'],r['group_id'],r['value']] for r in D7['result']['rows']]
    p.table(x,y,[width/3]*3,["sample_id · int64","group_id · int64","value · int64"],rows,48)


def draw_d7(p,fig):
    if fig==1:
        shared_scene(p,portal=True)
    elif fig==2:
        p.button(32,190,"← Neighborhood")
        p.rect(130,280,1180,455,width=2)
        p.text(154,318,"R17 · one backing resource",20,True)
        p.rect(160,355,660,340)
        p.text(186,394,"T1",24,True)
        p.note(186,434,["sample_id   int64","group_id     int64","value          int64","Sample S1 · 6 supplied synthetic rows"])
        p.button(186,621,"Explore sample",True)
        p.rect(858,355,418,340)
        p.text(882,394,"T2",24,True)
        p.text(882,441,"Schema not loaded",16)
        p.note(32,835,["Entry reveals declared structure. Room area has no quantitative meaning.","Explore sample prepares the draft; Run query is a separate action."])
    elif fig==3:
        p.text(32,206,"R17 / T1 / Q1 · Canvas selected · Complete for sample S1 only",17,True)
        for x,w,title,lines in [(48,375,"Source · T1",["Sample S1 · 6 rows","sample_id / group_id / value","Declared synthetic schema"]),(545,330,"Filter",["group_id = 2","One typed equality predicate","No source mutation"]),(997,390,"Result Q1",["102    2    13","104    2    34","105    2    55"])]:
            p.rect(x,300,w,280)
            p.text(x+22,340,title,20,True)
            p.note(x+22,393,lines)
        p.arrow(423,430,545,430,"query step")
        p.arrow(875,430,997,430,"result")
        p.button(32,674,"Run query")
        p.note(32,765,["Shown after explicit Run. The same draft, source and result are retained in Browse.","Query dependencies differ from dashed resource associations; a result is not a new resource."])
    else:
        p.text(32,206,"R17 / T1 / Q1 · Browse selected · Complete for sample S1 only",17,True)
        p.rect(32,248,1376,122)
        p.text(54,284,"Source: T1   /   Scope: sample S1 (6 rows)",17,True)
        p.text(54,332,"Filter: group_id = 2",17,mono=True)
        p.button(1210,292,"Run query",width=174)
        sample_table(p,32,433,1376)
        p.note(32,759,["Result: synthetic-q1-result-1 · rows 102, 104, 105 · complete for S1 only","Switching Canvas/Browse does not rerun Q1 or replace its observation basis."])


def draw_d8(p,fig):
    if fig==1:
        for k,name in enumerate(["Stadium","Park","Fairground"]):
            cx=240+k*480
            p.text(cx,229,name,22,True,anchor="middle")
            if k==0:
                p.ellipse(cx,510,192,177)
                p.ellipse(cx,510,116,98)
            positions=[(-120,-116),(95,-116),(146,55),(0,158),(-150,55)]
            for (dx,dy),group,count in zip(positions,'ABCDE',[600,500,400,300,200]):
                if k==1:
                    p.ellipse(cx+dx,510+dy,52,28)
                elif k==2:
                    p.rect(cx+dx-52,510+dy-27,104,54)
                p.text(cx+dx,515+dy,f"{group} · {count}",14,True,anchor="middle")
            p.rect(cx-72,460,144,92,width=2)
            p.text(cx,489,"R17",19,True,anchor="middle")
            p.text(cx,524,"T1 / T2",15,anchor="middle")
            p.text(cx,764,"2,000 disclosed associations",15,anchor="middle")
        p.note(32,835,["Three layouts of the same resource and the same five groups. Byte-height scale is inactive.","Sectors are schematic, not seats or concurrent users. Associations establish neither access nor active use."])
    elif fig==2:
        for i,horizon in enumerate(["Past","Now","Day","Week","Month","Year","Decade"]):
            p.text(32+i*100,207,horizon,17,horizon=="Year")
        p.line(532,218,572,218,3)
        # Comparison is a schematic envelope, with exact values in the adjoining table.
        x=245; y=743
        for h,w,label in [(450,200,"High · 762 MiB"),(330,177,"Steady · 397 MiB"),(215,155,"Low · 214.5 MiB")]:
            cube(p,x,y,w,h,dash=True)
            p.text(x+w+46,y-h-10,label,15)
        resource(p,x,y,"table",w=130,h=93,label="Now · 32 MiB")
        p.line(100,482,681,482,2)
        p.text(85,466,"256 MiB planning level · assumption",14,True)
        p.table(770,284,[220,180,230],["Horizon","Days","Steady +1 MiB/day"],[["Now","0","32 MiB"],["Day","1","33 MiB"],["Week","7","39 MiB"],["Month","30","62 MiB"],["Year","365","397 MiB"],["Decade","3,650","3,682 MiB"]])
        p.note(770,682,["Observed: −30d 16 MiB · −7d 28 MiB · now 32 MiB","Cases: +0.5 / +1 / +2 MiB per elapsed day","Solid = supplied observation","Dashed = conditional case, not a forecast"])
        p.text(32,866,"One fixed schematic scale across cases. Historical samples do not imply available historical rows.",14)
    else:
        p.text(32,213,"R17 / Growth readiness / One year · selected +1 MiB per day",19,True)
        p.table(32,255,[300,350,350,376],["Question","Requirement / assumption","Evidence","Assessment"],[
            ["Current-value size","256 MiB planning level","397 MiB at 365 days","Exceeds assumption"],
            ["Physical capacity","Not supplied","No physical accounting","Unknown"],
            ["Write contention","Not supplied","2,000 associations ≠ writers","Unknown"],
            ["Query performance","Not supplied","No matching workload proof","Unknown"],
            ["Recovery time","Not supplied","No matching recovery proof","Unknown"],
            ["Lifecycle","Existing declared policy","No change proposed","Independent decision"],
        ],61)
        p.note(32,720,["At +1 MiB/day: reaches 256 MiB in 224 days; exceeds it thereafter.","Across low/high cases: reaches the planning level in 448 / 112 days.","An arithmetic budget fit cannot prove readiness. No overall health score."])
        p.button(32,832,"Edit assumptions")
        p.text(220,854,"Local scenario only · does not resize, migrate or expire resources",14)


def grammar_figures():
    specs=[("One definition, several representations","SQL / visual composition · draft revision 13 · accepted revision 12","d1-01-definition.svg"),
        ("Meaning before theme","Stable semantic dimensions · monochrome presentation tokens","d1-02-dimensions.svg"),
        ("An exact view, followed by a newer one","Explore / items · Follow changes is snapshot refresh","d1-03-reactive.svg"),
        ("Review the migration, recover each step","Application change-24 · base 12 → target 13 · proposed lifecycle","d1-04-migration.svg")]
    for fig,(title,sub,name) in enumerate(specs,1):
        p=Plate(title,sub,True,"Explore" if fig in [1,3] else "Activity")
        if fig==1:
            p.text(240,207,"Definition · SQL",17,True)
            p.text(866,207,"Rendered preview · fixture",17,True)
            p.rect(240,235,576,370)
            lines=["-- PROPOSED; not executable SQL","CREATE SCREEN board.workspace.explore","WITH (renderer = 'worksheet',","      binding = 'items');","","CREATE BINDING board.items WITH (","  kind = 'finite_query',","  source = 'items',","  refresh = 'follow_changes');"]
            for i,line in enumerate(lines):
                p.text(260,268+i*31,line,14,mono=True)
            p.rect(850,235,558,370)
            p.text(872,273,"Explore / items",20,True)
            p.text(872,310,"SELECT id, value FROM items LIMIT 32",14,mono=True)
            p.table(872,340,[240,274],["id","value"],[["102","13"],["104","34"],["105","55"]])
            p.text(872,562,"Fixture · Q17 · basis 104 · complete",13)
            p.table(240,660,[210,370,588],["Reference","Meaning","Authority"],[["items","Exact declared source/schema","Query service + current resource rights"],["Follow changes","Qualified watch and budget","Explicit view-session admission"],["Apply definition","Conditional revision 12 → 13","Separate attributable operator"]])
        elif fig==2:
            for i,kind in enumerate(["table","kv","document"]):
                resource(p,285+i*245,403,kind,w=110,h=116,label=kind.upper())
            process(p,1184,403,36,12,scale=1.35,label="Inbox 36 / Outbox 12",age=1080)
            p.table(240,531,[235,360,573],["Dimension","Monochrome expression","Invariant"],[
                ["Selection / focus","Perimeter / focus outline","Never permission or health"],
                ["Association","Dashed, labeled edge","No traffic or ownership implied"],
                ["Dependency","Solid arrow + verb","Exact declared reference"],
                ["Proposed change","Before / After + dashed frame","Draft is not accepted state"],
                ["Unknown / denied","Explicit text / cleared content","No fabricated zero or stale disclosure"],
                ["Theme tokens","Ink, surface, type, spacing","Cannot change semantic encoding"],
            ],48)
        elif fig==3:
            p.text(240,208,"SELECT id, value FROM items WHERE id > 103",18,mono=True)
            p.button(1150,183,"Pause following",width=258)
            p.text(240,259,"Displayed: Q17 · query generation 7 · exact basis 104",17,True)
            p.text(240,292,"Refresh pending through 107 · candidate verifying · draft 8 differs",14)
            p.table(240,330,[355,355,458],["id","value","Result basis"],[["102","13","104"],["104","34","104"],["105","55","104"]],45)
            p.text(240,566,"Other states of this same view",18,True)
            p.table(240,591,[225,480,463],["State","Visible meaning","Next permitted step"],[
                ["Paused","Last permitted basis retained","Explicit Follow changes"],
                ["Disconnected","Original basis; no freshness claim","Resume or report reset"],
                ["Reset required","Notification coverage unavailable","Authorized resnapshot"],
                ["Denied","Protected rows and candidates cleared","No automatic new query"],
            ],52)
            p.text(240,883,"A new result replaces rows and profile together after complete verification.",14)
        else:
            p.text(240,209,"Acting as: provisioned operator · exact realm and grants required",16,True)
            p.rect(240,240,550,190,dash=True)
            p.rect(818,240,590,190,dash=True)
            p.note(260,277,["Interface revision 12","items.v1 binding","Compatible readers still active"],"Before")
            p.note(838,277,["Interface revision 13","items.v2 only after verified backfill","Existing command targets remain frozen"],"Proposed after")
            p.table(240,484,[190,354,260,364],["Step","Public operation","Disposition","Recovery"],[
                ["1 · Expand","Declare supported target","Completed","Receipt retained"],
                ["2 · Backfill","Bounded page batch","Uncertain · op-812","Recover same operation"],
                ["3 · Verify","Check coverage + schema","Blocked on step 2","Do not switch consumers"],
                ["4 · Publish","Conditional interface revision","Not admitted","Requires current base + rights"],
            ],57)
            p.button(240,780,"Recover op-812",True)
            p.button(446,780,"Apply",unavailable=True,width=100)
            p.text(565,803,"Unavailable while a prior step is uncertain",14)
            p.text(240,868,"No cross-resource transaction. Reverting presentation cannot reverse accepted effects.",14)
        p.save(HERE/'images'/name)


def atlas_figures():
    figures=[]
    for review in range(1,9):
        doc=(ATLAS/f'D{review}.md').read_text()
        matches=re.findall(r'### Figure (\d+): ([^\n]+)\n\n!\[([^\]]+)\]\((images/[^)]+)\)',doc)
        for num,title,alt,original in matches:
            num=int(num)
            short={1:"Browser and relief",2:"Inbox, outbox and age",3:"Process scale",4:"Regional scale",5:"Resource cityscape",6:"Emphasis and zoom",7:"Resource workspace",8:"Venues and growth"}[review]
            p=Plate(f"{short} / {title.split(' — ')[0]}",f"Atlas D{review} · Figure {num} · monochrome translation · synthetic evidence",review<=3)
            globals()[f'draw_d{review}'](p,num)
            target=f'images/monochrome/d{review}-{num:02d}.svg'
            p.save(ATLAS/target)
            figures.append({'review':f'D{review}','figure':num,'title':title,'original':original,'redraw':target,'originalAlt':alt,'alt':f'Monochrome Atlas D{review}, Figure {num}: {title}. Synthetic vector study.','status':'synthetic_vector_redraw','note':'Semantic translation; not a trace or calibrated metric plot.'})
    assert len(figures)==34
    (ATLAS/'monochrome-fixture.json').write_text(json.dumps({'synthetic':True,'status':'D10 review inventory, not a runtime schema.','sourceReviews':[f'D{i}.md' for i in range(1,9)],'figures':figures},indent=2,ensure_ascii=False)+'\n')
    return figures


def gallery(figures):
    # Standalone, self-contained navigation; all images are local and unchanged.
    links=' '.join(f'<a href="#d{i}">D{i}</a>' for i in range(1,9))
    out=['<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Board Atlas — monochrome review</title>',
         '<style>body{margin:0;background:white;color:black;font:16px/1.5 system-ui,sans-serif}header,main{max-width:1440px;margin:auto;padding:24px}header{border-bottom:1px solid black}h1{font-size:28px}nav{display:flex;gap:20px;flex-wrap:wrap}a{color:inherit}section{margin:48px 0}figure{margin:32px 0 64px}img{display:block;width:100%;height:auto;border:1px solid black}figcaption{margin-top:12px}summary{cursor:default;padding:12px 0}details img{max-width:100%}@media(max-width:600px){header,main{padding:16px}h1{font-size:24px}}</style>',
         '<header><h1>Board Atlas — monochrome review</h1><p>All 34 figures from D1–D8, redrawn for D10. Synthetic design evidence; no implementation or scale claim.</p>',
         '<p><a href="D10.md">D10 review</a> · <a href="../board-grammar/D1.md">Board grammar D1</a></p>',f'<nav aria-label="Review sequence">{links}</nav></header><main>']
    for i in range(1,9):
        out.append(f'<section id="d{i}"><h2>Atlas D{i}</h2>')
        for f in [a for a in figures if a['review']==f'D{i}']:
            out.append(f'<figure><a href="{f["redraw"]}"><img src="{f["redraw"]}" loading="lazy" width="1440" height="960" alt="Monochrome redraw: {escape(f["alt"],quote=True)}"></a><figcaption><strong>Figure {f["figure"]}: {escape(f["title"])}</strong> · <a href="D{i}.md">Original review and evidence limits</a></figcaption><details><summary>Compare original rendered study</summary><img src="{f["original"]}" loading="lazy" alt="Original rendered study for comparison"></details></figure>')
        out.append('</section>')
    out.append('</main></html>')
    (ATLAS/'monochrome.html').write_text('\n'.join(out)+'\n')


if __name__ == '__main__':
    grammar_figures()
    gallery(atlas_figures())
    print('Wrote 4 Board grammar studies, 34 Atlas redraws, the mapping fixture and gallery.')
