// Server-only Supabase Edge Function design. NOT deployed until owner identity and
// secret-scoped GitHub installation token are configured and verified.
// Never bundle or import this file into GitHub Pages.
import { createClient } from "npm:@supabase/supabase-js@2.57.0";
const OWNER="TheOsmanYILDIRIM", REPO="oyun", BRANCH="main";
const ALLOWED_MATERIALS=new Set(["grass","soil","stone"]);
const ALLOWED_BIOMES=new Set(["meadow","forest","rocky"]);
function fail(status:number,error:string){return Response.json({error},{status,headers:{"Cache-Control":"no-store"}})}
function decodedBase64(s:string){try{return Uint8Array.from(atob(s),c=>c.charCodeAt(0))}catch{return null}}
Deno.serve(async request=>{
 if(request.method!=="POST")return fail(405,"method_not_allowed");
 const serverUrl=Deno.env.get("SUPABASE_URL"),anonKey=Deno.env.get("SUPABASE_ANON_KEY");
 const ownerUser=Deno.env.get("OSMAN_TERRAIN_OWNER_UID"),githubToken=Deno.env.get("OSMAN_TERRAIN_GITHUB_TOKEN");
 if(!serverUrl||!anonKey||!ownerUser||!githubToken)return fail(503,"not_configured");
 const origin=request.headers.get("Origin")||"";
 if(origin!=="https://theosmanyildirim.github.io")return fail(403,"invalid_origin");
 const auth=request.headers.get("Authorization")||"";
 if(!auth.startsWith("Bearer "))return fail(401,"auth_required");
 const supabase=createClient(serverUrl,anonKey,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data:{user},error}=await supabase.auth.getUser(auth.slice(7));
 if(error||!user||user.id!==ownerUser)return fail(403,"owner_required");
 if(Number(request.headers.get("content-length")||0)>9_000_000)return fail(413,"payload_too_large");
 let body:Record<string,unknown>;
 try{body=await request.json()}catch{return fail(400,"invalid_json")}
 const material=String(body.material||""),biome=String(body.biome||""),variant=Number(body.variant),kind=String(body.kind||"");
 if(!ALLOWED_MATERIALS.has(material)||!ALLOWED_BIOMES.has(biome)||![0,1].includes(variant)||!["albedo","normal"].includes(kind))return fail(400,"invalid_catalog");
 const encoded=String(body.png_base64||"");
 if(encoded.length>8_000_000||!/^[A-Za-z0-9+/]+={0,2}$/.test(encoded))return fail(413,"invalid_png_payload");
 const bytes=decodedBase64(encoded);
 if(!bytes||bytes.length<33||bytes.length>6_000_000)return fail(413,"invalid_png_size");
 const signature=[137,80,78,71,13,10,26,10];
 if(!signature.every((v,i)=>bytes[i]===v))return fail(400,"invalid_png_signature");
 const reader=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);
 const width=reader.getUint32(16),height=reader.getUint32(20);
 if(width!==height||width<256||width>4096)return fail(400,"not_square");
 const digest=await crypto.subtle.digest("SHA-256",bytes);
 const hash=Array.from(new Uint8Array(digest)).map(v=>v.toString(16).padStart(2,"0")).join("");
 const path=`assets/terrain/drafts/${material}/${biome}/v${variant}/${kind}-${hash.slice(0,20)}.png`;
 const api=`https://api.github.com/repos/${OWNER}/${REPO}/contents/${path}`;
 const headers={"Accept":"application/vnd.github+json","Authorization":"Bearer "+githubToken,"X-GitHub-Api-Version":"2022-11-28"};
 const existing=await fetch(api+"?ref="+BRANCH,{headers});
 if(existing.status===200)return Response.json({status:"already_exists",path,sha256:hash},{headers:{"Cache-Control":"no-store"}});
 if(existing.status!==404)return fail(502,"github_lookup_failed");
 const response=await fetch(api,{method:"PUT",headers:{...headers,"Content-Type":"application/json"},body:JSON.stringify({message:`Add reviewed terrain draft ${material}/${biome}/${kind} ${hash.slice(0,10)}`,content:encoded,branch:BRANCH})});
 if(!response.ok)return fail(response.status===409?409:502,"github_write_failed");
 const result=await response.json();
 return Response.json({status:"uploaded_draft",path,sha256:hash,commit:result.commit?.sha},{headers:{"Cache-Control":"no-store"}});
});
