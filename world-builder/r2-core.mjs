// Round 2 authoring-only model. No runtime/save mutations.
export const BUNDLE_FORMAT='osman-r2-editor-bundle-v1';
export const clone=x=>structuredClone(x);
const EPS=1e-7;
const requireOk=(ok,msg)=>{if(!ok)throw Error(msg)};
const keys=(o,expected,label)=>{requireOk(o&&typeof o==='object'&&!Array.isArray(o),label+' object');requireOk(Object.keys(o).every(k=>expected.includes(k))&&expected.every(k=>Object.hasOwn(o,k)),label+' fields')};
const id=(v,p)=>typeof v==='string'&&new RegExp('^'+p+':[a-z][a-z0-9-]{1,63}$').test(v);
const num=v=>typeof v==='number'&&Number.isFinite(v)&&Math.abs(v)<=1e6;
const point=p=>Array.isArray(p)&&p.length===2&&p.every(num);
const line=(p,q)=>Math.hypot(p[0]-q[0],p[1]-q[1]);
const cross=(a,b,p)=>(b[0]-a[0])*(p[1]-a[1])-(b[1]-a[1])*(p[0]-a[0]);
export const onSegment=(a,b,p)=>Math.abs(cross(a,b,p))<=EPS&&p[0]>=Math.min(a[0],b[0])-EPS&&p[0]<=Math.max(a[0],b[0])+EPS&&p[1]>=Math.min(a[1],b[1])-EPS&&p[1]<=Math.max(a[1],b[1])+EPS;
const edges=p=>p.map((v,i)=>[v,p[(i+1)%p.length]]);
const isCross=(a,b,c,d)=>{const [x,y,z,w]=[cross(a,b,c),cross(a,b,d),cross(c,d,a),cross(c,d,b)];return ((x>EPS&&y< -EPS)||(x< -EPS&&y>EPS))&&((z>EPS&&w< -EPS)||(z< -EPS&&w>EPS))};
const intersects=(a,b,c,d)=>isCross(a,b,c,d)||onSegment(a,b,c)||onSegment(a,b,d)||onSegment(c,d,a)||onSegment(c,d,b);
export function location(poly,p){for(const [a,b] of edges(poly))if(onSegment(a,b,p))return 0;let inside=false;for(const [a,b] of edges(poly))if((a[1]>p[1])!==(b[1]>p[1])&&p[0]<a[0]+(p[1]-a[1])*(b[0]-a[0])/(b[1]-a[1]))inside=!inside;return inside?1:-1}
function witness(poly){for(let i=0;i<poly.length;i++){const a=poly[(i+poly.length-1)%poly.length],b=poly[i],c=poly[(i+1)%poly.length];if(cross(a,b,c)>EPS)return b.map((v,k)=>(98*v+a[k]+c[k])/100)}throw Error('no convex witness')}
export function polygon(poly,label='polygon'){requireOk(Array.isArray(poly)&&poly.length>=3&&poly.length<=96&&poly.every(point),label+' vertices');requireOk(new Set(poly.map(JSON.stringify)).size===poly.length,label+' duplicate vertex');requireOk(edges(poly).every(([a,b])=>line(a,b)>EPS),label+' zero edge');requireOk(edges(poly).reduce((s,[a,b])=>s+a[0]*b[1]-b[0]*a[1],0)>EPS,label+' CCW area');const ee=edges(poly);for(let i=0;i<ee.length;i++)for(let j=i+1;j<ee.length;j++)if(j!==i+1&&!(i===0&&j===ee.length-1))requireOk(!intersects(...ee[i],...ee[j]),label+' self intersection');return true}
function overlap(a,b){return edges(a).some(([p,q])=>edges(b).some(([r,s])=>isCross(p,q,r,s)))||a.some(p=>location(b,p)===1)||b.some(p=>location(a,p)===1)||location(b,witness(a))===1||location(a,witness(b))===1}
function support(poly,p,w){return edges(poly).some(([a,b])=>onSegment(a,b,p)&&Math.min(line(a,p),line(b,p))+EPS>=w/2)}
function segmentParams(a,b,c,d){const rx=b[0]-a[0],ry=b[1]-a[1],sx=d[0]-c[0],sy=d[1]-c[1],qx=c[0]-a[0],qy=c[1]-a[1],den=rx*sy-ry*sx,cap=v=>Math.max(0,Math.min(1,v));if(Math.abs(den)<=EPS){if(Math.abs(qx*ry-qy*rx)>EPS)return [];const rr=rx*rx+ry*ry;return rr<=EPS?[]:[cap((qx*rx+qy*ry)/rr),cap(((d[0]-a[0])*rx+(d[1]-a[1])*ry)/rr)]}const t=(qx*sy-qy*sx)/den,u=(qx*ry-qy*rx)/den;return t>=-EPS&&t<=1+EPS&&u>=-EPS&&u<=1+EPS?[cap(t)]:[]}
function insideUnion(a,b,regs){const ts=[0,1];for(const r of regs)for(const [c,d] of edges(r.polygon))ts.push(...segmentParams(a,b,c,d));ts.sort((p,q)=>p-q);for(let i=1;i<ts.length;i++){if(ts[i]-ts[i-1]<=EPS)continue;const t=(ts[i]+ts[i-1])/2,p=a.map((v,k)=>v+t*(b[k]-v));if(!regs.some(r=>location(r.polygon,p)>=0))return false}return true}
export function linePosition(points,p){let d=0;for(let i=1;i<points.length;i++){const a=points[i-1],b=points[i];if(onSegment(a,b,p))return d+line(a,p);d+=line(a,b)}return null}
const checkIds=(arr,p,label)=>{requireOk(Array.isArray(arr),label+' array');const used=new Set;for(const entry of arr){requireOk(id(entry.id,p)&&!used.has(entry.id),label+' id');used.add(entry.id)}};
const variants={meadow:['default','wildflower','dry'],forest:['default','clearing','dense'],rocky:['default','ridge','gravel']};
export function validateAuthored(m){
 keys(m,['format','schema_version','map_id','name','coordinate_space','projection','seed','generator_version','regions','connectors','features'],'authored');
 requireOk(m.format==='osman-worldbuild-v1'&&m.schema_version===1&&id(m.map_id,'worldmap')&&m.coordinate_space==='world'&&m.projection==='iso-45'&&m.generator_version===1&&Number.isInteger(m.seed)&&m.seed>=0&&m.seed<=2147483646&&typeof m.name==='string'&&m.name.length>0&&m.name.length<=100,'authored header');
 requireOk(m.regions.length>=1&&m.regions.length<=32&&m.connectors.length<=128&&m.features.length<=128,'authored count');
 checkIds(m.regions,'region','regions');checkIds(m.connectors,'connector','connectors');checkIds(m.features,'feature','features');
 const regions=new Map(m.regions.map(r=>[r.id,r]));
 for(const r of m.regions){keys(r,['id','name','biome','variant','polygon'],'region');requireOk(typeof r.name==='string'&&r.name.length>0&&r.name.length<=100&&variants[r.biome]?.includes(r.variant),'region biome/name');polygon(r.polygon,r.id)}
 for(let i=0;i<m.regions.length;i++)for(let j=i+1;j<m.regions.length;j++)requireOk(!overlap(m.regions[i].polygon,m.regions[j].polygon),'region overlap');
 for(const f of m.features){keys(f,['id','kind','intent_only','width','points'],'feature');requireOk(['path','water'].includes(f.kind)&&f.intent_only===true&&num(f.width)&&f.width>0&&f.width<=64&&Array.isArray(f.points)&&f.points.length>=2&&f.points.length<=96&&f.points.every(point),'feature fields');for(let i=1;i<f.points.length;i++)requireOk(line(f.points[i-1],f.points[i])>EPS&&insideUnion(f.points[i-1],f.points[i],m.regions),'feature outside/degenerate: '+f.id)}
 const openings=new Set;
 for(const c of m.connectors){keys(c,['id','regions','kind','anchor','width'],'connector');requireOk(Array.isArray(c.regions)&&c.regions.length===2&&c.regions[0]<c.regions[1]&&c.regions.every(x=>regions.has(x))&&['path','water'].includes(c.kind)&&point(c.anchor)&&num(c.width)&&c.width>0&&c.width<=64,'connector fields');const opening=JSON.stringify([c.regions,c.anchor,c.kind]);requireOk(!openings.has(opening),'duplicate physical opening');openings.add(opening);requireOk(c.regions.every(r=>support(regions.get(r).polygon,c.anchor,c.width)),'connector not on shared boundary');requireOk(m.features.some(f=>f.kind===c.kind&&f.width+EPS>=c.width&&linePosition(f.points,c.anchor)!==null),'connector missing feature')}
 return true;
}
function partition(areas,b){const rectangles=[];for(const a of areas){keys(a,['id','name','polygon','development'],'area');requireOk(typeof a.name==='string'&&a.name.length>0&&a.name.length<=100&&['authored_anchor','procedural_first'].includes(a.development)&&a.polygon.length===4,'area fields');polygon(a.polygon,a.id);const xs=[...new Set(a.polygon.map(p=>p[0]))].sort((x,y)=>x-y),ys=[...new Set(a.polygon.map(p=>p[1]))].sort((x,y)=>x-y);requireOk(xs.length===2&&ys.length===2&&xs[0]>=b.min_x&&ys[0]>=b.min_y&&xs[1]<=b.max_x&&ys[1]<=b.max_y,'area rectangle/bounds');requireOk(a.polygon.every(p=>xs.includes(p[0])&&ys.includes(p[1])),'area rectangle corners');rectangles.push([xs[0],ys[0],xs[1],ys[1]])}
 const xs=[...new Set([b.min_x,b.max_x,...rectangles.flatMap(r=>[r[0],r[2]])])].sort((a,b)=>a-b),ys=[...new Set([b.min_y,b.max_y,...rectangles.flatMap(r=>[r[1],r[3]])])].sort((a,b)=>a-b);
 for(let i=1;i<xs.length;i++)for(let j=1;j<ys.length;j++){const x=(xs[i-1]+xs[i])/2,y=(ys[j-1]+ys[j])/2;requireOk(rectangles.filter(r=>r[0]<=x&&x<r[2]&&r[1]<=y&&y<r[3]).length===1,'area partition gap/overlap')}
}
export function validateBundle(bundle){
 keys(bundle,['format','schema_version','manifest','authored'],'bundle');
 requireOk(bundle.format===BUNDLE_FORMAT&&bundle.schema_version===1,'bundle version');
 const m=bundle.manifest,a=bundle.authored;validateAuthored(a);
 keys(m,['format','schema_version','map_id','name','coordinate_space','projection','seed','generator_version','bounds','frontiers','generation','expansion','areas','authored_maps','sites','routes'],'manifest');
 requireOk(m.format==='osman-worldmap-v2'&&m.schema_version===2&&id(m.map_id,'worldmap')&&typeof m.name==='string'&&m.name.length>0&&m.name.length<=100&&m.coordinate_space==='world'&&m.projection==='iso-45'&&m.generator_version===1&&m.seed===a.seed,'manifest header');
 const b=m.bounds;keys(b,['min_x','min_y','max_x','max_y','units','enforcement'],'bounds');
 requireOk([b.min_x,b.min_y,b.max_x,b.max_y].every(num)&&b.max_x>b.min_x&&b.max_y>b.min_y&&b.max_x-b.min_x===b.max_y-b.min_y&&b.units==='world'&&b.enforcement==='design_only','bounds');
 requireOk(Array.isArray(m.frontiers)&&m.frontiers.length===4,'frontiers count');const frontierKinds={west:'highlands',north:'mountain_ridge',east:'sea_cliffs',south:'coastline'};const edgeSet=new Set;for(const f of m.frontiers){keys(f,['edge','form','blocking_intent'],'frontier');requireOk(['north','south','east','west'].includes(f.edge)&&['highlands','mountain_ridge','sea_cliffs','coastline','marshes'].includes(f.form)&&f.blocking_intent===true&&!edgeSet.has(f.edge),'frontier');edgeSet.add(f.edge)}
 keys(m.generation,['authored_target_min','authored_target_max','target_horizon','fallback','map_activation'],'generation');requireOk(num(m.generation.authored_target_min)&&num(m.generation.authored_target_max)&&m.generation.authored_target_min>=0&&m.generation.authored_target_min<=m.generation.authored_target_max&&m.generation.authored_target_max<=1&&m.generation.target_horizon==='world_maturity'&&m.generation.fallback==='generator-v1'&&m.generation.map_activation==='opt_in_future_adapter','generation');
 keys(m.expansion,['policy','preserve_global_coordinates','preserve_existing_ids'],'expansion');requireOk(m.expansion.policy==='adjacent_versioned_worldmaps'&&m.expansion.preserve_global_coordinates===true&&m.expansion.preserve_existing_ids===true,'expansion');
 checkIds(m.areas,'area','areas');requireOk(m.areas.length>=1&&m.areas.length<=32,'area count');partition(m.areas,b);
 requireOk(m.authored_maps.length===1,'R2 editor currently requires exactly one explicit authored source');checkIds(m.authored_maps,'worldmap','authored_maps');
 const ref=m.authored_maps[0];keys(ref,['id','area_id','path'],'authored map ref');requireOk(ref.id===a.map_id&&m.areas.some(x=>x.id===ref.area_id)&&/^data\/worldbuild\/[a-z0-9][a-z0-9_.-]*\.v1\.json$/.test(ref.path),'authored map ref path');
 const area=m.areas.find(x=>x.id===ref.area_id);
 for(const r of a.regions)for(const p of r.polygon)requireOk(location(area.polygon,p)>=0,'region outside parent area');
 checkIds(m.sites,'site','sites');checkIds(m.routes,'route','routes');requireOk(m.sites.length>=1&&m.sites.length<=256&&m.routes.length>=1&&m.routes.length<=128,'site/route counts');
 const regions=new Map(a.regions.map(r=>[r.id,r])),features=new Map(a.features.map(f=>[f.id,f])),sites=new Map(m.sites.map(s=>[s.id,s]));
 for(const s of m.sites){keys(s,['id','name','region_id','anchor','role','discover_step'],'site');requireOk(typeof s.name==='string'&&s.name.length>0&&s.name.length<=100&&regions.has(s.region_id)&&point(s.anchor)&&location(regions.get(s.region_id).polygon,s.anchor)===1&&['spawn','crossroads','ruin','crossing','vista','pass','waterfront','resource'].includes(s.role)&&Number.isInteger(s.discover_step)&&s.discover_step>=0&&s.discover_step<=255,'site fields: '+s.id)}
 requireOk(m.sites.some(s=>s.role==='spawn'),'missing spawn');
 let mains=0;
 for(const route of m.routes){keys(route,['id','kind','feature_id','sites'],'route');requireOk(['main','optional'].includes(route.kind)&&features.get(route.feature_id)?.kind==='path'&&Array.isArray(route.sites)&&route.sites.length>=2&&route.sites.length<=32&&new Set(route.sites).size===route.sites.length,'route fields: '+route.id);const feat=features.get(route.feature_id);let prev=-1,previous=null;
 for(const sid of route.sites){const site=sites.get(sid);requireOk(site,'route site missing');const p=linePosition(feat.points,site.anchor);requireOk(p!==null&&p>prev+EPS,'route site off line/order');if(previous&&previous.region_id!==site.region_id){const graph=new Map;for(const c of a.connectors){if(c.kind!=='path'||linePosition(feat.points,c.anchor)===null)continue;for(const [from,to] of [[...c.regions],[...c.regions].reverse()])graph.set(from,[...(graph.get(from)||[]),to])}const seen=new Set([previous.region_id]),q=[previous.region_id];for(const n of q)for(const dest of graph.get(n)||[])if(!seen.has(dest)){seen.add(dest);q.push(dest)}requireOk(seen.has(site.region_id),'route connector gap')}
 prev=p;previous=site}
 if(route.kind==='main'){mains++;requireOk(sites.get(route.sites[0]).role==='spawn','main must start spawn')}}
 requireOk(mains===1,'exactly one main route');return true;
}
export function modify(bundle,fn){const draft=clone(bundle);fn(draft);validateBundle(draft);return draft}
export function round(p){return p.map(n=>Math.round(n*10)/10)}
export function moveSharedVertex(bundle,regionId,index,to){return modify(bundle,d=>{const region=d.authored.regions.find(x=>x.id===regionId);requireOk(region&&region.polygon[index]&&point(to),'vertex selection');const before=region.polygon[index].slice();for(const r of d.authored.regions)r.polygon=r.polygon.map(p=>line(p,before)<EPS?round(to):p);for(const c of d.authored.connectors)if(line(c.anchor,before)<EPS)c.anchor=round(to);for(const f of d.authored.features)f.points=f.points.map(p=>line(p,before)<EPS?round(to):p);for(const s of d.manifest.sites)if(line(s.anchor,before)<EPS)s.anchor=round(to)})}
export function parseBundle(text){requireOk(text.length<=4e6,'oversize bundle');const raw=JSON.parse(text);validateBundle(raw);return raw}
