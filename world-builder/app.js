// World Builder v2 — authored terrain modules in continuous world coordinates.
// Previous v1 localStorage and exported JSON remain untouched.
const $=id=>document.getElementById(id),canvas=$("world"),ctx=canvas.getContext("2d"),viewport=$("viewport");
const BUILD="__BUILD_SHA__",KEY="osman-worldbuilder-v2",clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const ISO={x:0.7071067811865476,y:0.3535533905932738};
const project=(p)=>({x:(p.x-p.y)*ISO.x,y:(p.x+p.y)*ISO.y-(p.z||0)});
const unproject=p=>({x:(p.x/ISO.x+p.y/ISO.y)/2,y:(p.y/ISO.y-p.x/ISO.x)/2});
const authored=[
 {id:"clearing",type:"grass",outline:[[40,180],[95,85],[210,35],[310,70],[370,135],[350,215],[290,295],[205,335],[115,300]],ports:[{id:"east",x:330,y:210},{id:"south",x:205,y:320}]},
 {id:"ridge",type:"moss",outline:[[285,135],[355,90],[460,110],[525,160],[565,255],[510,305],[400,330],[325,280]],ports:[{id:"west",x:330,y:210},{id:"east",x:540,y:245}]},
 {id:"riverbend",type:"grass",outline:[[180,310],[275,265],[365,290],[420,350],[430,445],[375,520],[280,555],[190,505],[145,420]],ports:[{id:"north",x:205,y:320},{id:"east",x:410,y:415}]}
];
const paths=[
 {type:"path",points:[[110,110],[190,150],[255,185],[330,210],[405,210],[495,265]]},
 {type:"path",points:[[330,210],[295,278],[230,365],[260,450],[350,490]]},
 {type:"water",points:[[165,515],[220,460],[275,405],[300,335],[325,265],[375,205],[450,140]]}
];
const decorations=[
 ["tree",135,165],["tree",170,94],["tree",240,78],["tree",290,132],["tree",90,220],["tree",215,285],
 ["tree",405,160],["tree",460,190],["tree",510,235],["tree",355,290],["tree",200,440],["tree",325,425],
 ["rock",375,150],["rock",430,275],["rock",365,450],["rock",200,370]
].map(([type,x,y])=>({type,x,y}));
function fresh(){return{version:2,modules:structuredClone(authored),paths:structuredClone(paths),objects:structuredClone(decorations),note:""}}
let scene;try{const obj=JSON.parse(localStorage.getItem(KEY));scene=obj?.version===2&&Array.isArray(obj.modules)&&Array.isArray(obj.paths)&&Array.isArray(obj.objects)?obj:fresh()}catch{scene=fresh()}
let scale=0.8,offset={x:0,y:0},tool="pan",brush=18,history=[],pointers=new Map(),gesture=null,last=null,currentPath=null;
const show={forest:true,water:true,path:true,details:true};
function save(){try{localStorage.setItem(KEY,JSON.stringify(scene))}catch{status("Yerel kayıt dolu; JSON olarak dışa aktar.")}}
function status(t){$("message").textContent=t}
function snapshot(){history.push(JSON.stringify(scene));if(history.length>35)history.shift()}
const P=p=>project({x:p[0],y:p[1]});
function poly(points,color,strokeColor){const p=points.map(P);if(!p.length)return;ctx.beginPath();ctx.moveTo(p[0].x,p[0].y);for(let i=1;i<p.length;i++)ctx.lineTo(p[i].x,p[i].y);ctx.closePath();ctx.fillStyle=color;ctx.fill();if(strokeColor){ctx.strokeStyle=strokeColor;ctx.lineWidth=2;ctx.stroke()}}
function ribbon(points,width,color){const p=points.map(P);if(p.length<2)return;ctx.beginPath();ctx.moveTo(p[0].x,p[0].y);for(let i=1;i<p.length-1;i++){ctx.quadraticCurveTo(p[i].x,p[i].y,(p[i].x+p[i+1].x)/2,(p[i].y+p[i+1].y)/2)}ctx.lineTo(p.at(-1).x,p.at(-1).y);ctx.strokeStyle=color;ctx.lineWidth=width*ISO.x;ctx.lineCap="round";ctx.lineJoin="round";ctx.stroke()}
function tree(o){const p=project(o);ctx.fillStyle="#253e3299";ctx.beginPath();ctx.ellipse(p.x+5,p.y+6,12,5,0,0,Math.PI*2);ctx.fill();ctx.fillStyle="#64523b";ctx.fillRect(p.x-2,p.y-19,4,19);for(const [x,y,r,c] of [[-7,-24,13,"#355b43"],[8,-26,15,"#426e50"],[0,-37,14,"#5b8261"]]){ctx.beginPath();ctx.ellipse(p.x+x,p.y+y,r,r*.78,0,0,Math.PI*2);ctx.fillStyle=c;ctx.fill()}}
function rock(o){const p=project(o);ctx.beginPath();ctx.moveTo(p.x-11,p.y+3);ctx.lineTo(p.x-3,p.y-11);ctx.lineTo(p.x+9,p.y-7);ctx.lineTo(p.x+13,p.y+5);ctx.closePath();ctx.fillStyle="#7d8981";ctx.fill();ctx.strokeStyle="#4c5b54";ctx.stroke()}
function draw(){const w=viewport.clientWidth,h=viewport.clientHeight;const dpr=Math.min(devicePixelRatio||1,2);if(canvas.width!==Math.round(w*dpr)||canvas.height!==Math.round(h*dpr)){canvas.width=Math.round(w*dpr);canvas.height=Math.round(h*dpr)}ctx.setTransform(dpr,0,0,dpr,0,0);ctx.fillStyle="#364941";ctx.fillRect(0,0,w,h);ctx.save();ctx.translate(offset.x,offset.y);ctx.scale(scale,scale);
for(const m of scene.modules)poly(m.outline,m.type==="moss"?"#677d58":"#8fa777","#495c49");
for(const p of scene.paths){if(!show[p.type])continue;ribbon(p.points,p.type==="water"?38:25,p.type==="water"?"#4b8787":"#8d7757");ribbon(p.points,p.type==="water"?30:17,p.type==="water"?"#77b6b5":"#c2a77e")}
const objects=scene.objects.slice().sort((a,b)=>a.x+a.y-(b.x+b.y));for(const o of objects){if(o.type==="tree"&&show.forest)tree(o);if(o.type==="rock"&&show.details)rock(o)}
if(show.details)for(const m of scene.modules)for(const port of m.ports||[]){const p=project(port);ctx.beginPath();ctx.arc(p.x,p.y,4,0,Math.PI*2);ctx.fillStyle="#f4d995";ctx.fill()}
ctx.restore();$("zoomInfo").textContent=Math.round(scale*100)+"%"}
function bounds(){const pts=scene.modules.flatMap(m=>m.outline.map(P));return{left:Math.min(...pts.map(p=>p.x)),right:Math.max(...pts.map(p=>p.x)),top:Math.min(...pts.map(p=>p.y))-55,bottom:Math.max(...pts.map(p=>p.y))+30}}
function fit(){const b=bounds(),w=viewport.clientWidth,h=viewport.clientHeight;scale=Math.min(w/(b.right-b.left+70),h/(b.bottom-b.top+70));offset={x:(w-(b.left+b.right)*scale)/2,y:(h-(b.top+b.bottom)*scale)/2};draw()}
function screen(e){const b=canvas.getBoundingClientRect();return{x:e.clientX-b.left,y:e.clientY-b.top}}
function world(s){return unproject({x:(s.x-offset.x)/scale,y:(s.y-offset.y)/scale})}
function zoom(f,p={x:viewport.clientWidth/2,y:viewport.clientHeight/2}){const old=scale;scale=clamp(scale*f,.2,4);offset.x=p.x-(p.x-offset.x)*scale/old;offset.y=p.y-(p.y-offset.y)*scale/old;draw()}
function pinch(){const a=[...pointers.values()];return{mid:{x:(a[0].x+a[1].x)/2,y:(a[0].y+a[1].y)/2},dist:Math.hypot(a[0].x-a[1].x,a[0].y-a[1].y)}}
canvas.onpointerdown=e=>{if(e.pointerType==="mouse"&&e.button!==0)return;canvas.setPointerCapture(e.pointerId);const p=screen(e);pointers.set(e.pointerId,p);if(pointers.size===2){gesture=pinch();currentPath=null;return}if(pointers.size!==1)return;last=p;if(tool==="pan")return;const q=world(p);snapshot();if(tool==="tree"||tool==="rock")scene.objects.push({type:tool,...q});else if(tool==="erase"){scene.objects=scene.objects.filter(o=>Math.hypot(o.x-q.x,o.y-q.y)>brush*1.5)}else{currentPath={type:tool,points:[[q.x,q.y]]};scene.paths.push(currentPath)}save();draw()};
canvas.onpointermove=e=>{if(!pointers.has(e.pointerId))return;const p=screen(e);pointers.set(e.pointerId,p);if(pointers.size===2){const n=pinch();if(gesture){offset.x+=n.mid.x-gesture.mid.x;offset.y+=n.mid.y-gesture.mid.y;zoom(n.dist/Math.max(1,gesture.dist),n.mid)}gesture=n;return}if(!last)return;if(tool==="pan"){offset.x+=p.x-last.x;offset.y+=p.y-last.y}else if(currentPath){const q=world(p),prev=currentPath.points.at(-1);if(Math.hypot(q.x-prev[0],q.y-prev[1])>5)currentPath.points.push([q.x,q.y])}last=p;draw()};
function up(e){pointers.delete(e.pointerId);if(pointers.size<2)gesture=null;if(!pointers.size){if(currentPath?.points.length===1)scene.paths.pop();currentPath=null;save()}last=null;draw()}
canvas.onpointerup=up;canvas.onpointercancel=up;canvas.addEventListener("wheel",e=>{e.preventDefault();zoom(e.deltaY<0?1.15:.87,screen(e))},{passive:false});
$("zoomIn").onclick=()=>zoom(1.2);$("zoomOut").onclick=()=>zoom(.82);$("homeView").onclick=fit;
document.querySelectorAll("[data-tool]").forEach(b=>b.onclick=()=>{tool=b.dataset.tool;document.querySelectorAll("[data-tool]").forEach(x=>x.classList.toggle("selected",x===b));status("Araç: "+b.textContent.trim())});
$("size").oninput=e=>{$("sizeVal").textContent=brush=+e.target.value};
document.querySelectorAll("[data-layer]").forEach(e=>e.onchange=()=>{show[e.dataset.layer]=e.checked;draw()});
$("undo").onclick=()=>{if(history.length){scene=JSON.parse(history.pop());save();draw()}};
$("resetScene").onclick=()=>{if(confirm("V2 sahnesi sıfırlansın mı? Eski v1 tasarım kaydı korunur.")){snapshot();scene=fresh();save();fit()}};
$("newSeed").disabled=true;$("seed").disabled=true;$("seed").value=0;$("seed").title="Rastgele dünya kaldırıldı; el yapımı modül sistemi aktif.";
$("directorNote").value=scene.note||"";$("directorNote").oninput=e=>{scene.note=e.target.value;save()};
function download(name,blob){const a=document.createElement("a"),u=URL.createObjectURL(blob);a.href=u;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(u),1500)}
$("exportJson").onclick=()=>download("world-builder-v2.json",new Blob([JSON.stringify(scene,null,2)],{type:"application/json"}));
$("exportPng").onclick=()=>canvas.toBlob(b=>b&&download("world-builder-isometric.png",b),"image/png");
$("importJson").onclick=()=>$("importFile").click();
$("importFile").onchange=async e=>{try{const f=e.target.files[0];if(!f)return;if(f.size>2000000)throw Error("Dosya büyük");const s=JSON.parse(await f.text());if(s.version!==2||!Array.isArray(s.modules)||!Array.isArray(s.paths)||!Array.isArray(s.objects))throw Error("V2 tasarım JSON gerekli");snapshot();scene=s;save();fit();status("V2 tasarımı açıldı")}catch(err){status("İçe aktarma: "+err.message)}e.target.value=""};
$("copyFeedback").onclick=async()=>{try{await navigator.clipboard.writeText("World Builder V2 / "+(scene.note||"")+" / modules "+scene.modules.length);status("Yönetmen notu kopyalandı")}catch{status("Kopyalama izni verilmedi")}};
$("buildStatus").textContent=BUILD.slice(0,9)+" • V2 iso";
$("checkUpdate").onclick=async()=>{try{const r=await fetch("./build.json?probe="+Date.now(),{cache:"no-store"});if(!r.ok)throw Error("HTTP "+r.status);const d=await r.json();if(d.sha&&d.sha!==BUILD&&confirm("Yeni sürüm açılsın mı? Yerel tasarımlar korunur."))location.href="./latest.html?build="+encodeURIComponent(d.sha)+"&_="+Date.now();else status("Sürüm kontrol edildi")}catch(err){status(err.message)}};
window.addEventListener("resize",()=>draw());fit();