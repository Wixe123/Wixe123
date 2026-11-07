// Browser side of render.js: draws an emulator snapshot with three.js and HTML.
import * as THREE from 'three';
import { RoomEnvironment } from '/three/examples/jsm/environments/RoomEnvironment.js';
window.renderSnap = async function(S){
  const FONT={GothamBold:'700',GothamBlack:'900',GothamMedium:'500',GothamSemibold:'600',SourceSansBold:'700',SourceSansSemibold:'600',ArialBold:'700',FredokaOne:'700',LuckiestGuy:'900',Bangers:'900',Oswald:'600',Highway:'600',SciFi:'600',Arcade:'700'};
  const W=S.view.w,H=S.view.h,INSET=S.view.inset;
  const canvas=document.getElementById('c');
  const R=new THREE.WebGLRenderer({canvas,antialias:true,preserveDrawingBuffer:true});
  R.setSize(W,H,false);canvas.style.width=W+'px';canvas.style.height=H+'px';
  R.shadowMap.enabled=true;R.shadowMap.type=THREE.PCFSoftShadowMap;
  R.toneMapping=THREE.ACESFilmicToneMapping;R.toneMappingExposure=1.0*Math.pow(2,S.lighting.exp||0);
  R.outputColorSpace=THREE.SRGBColorSpace;
  const col=(c)=>new THREE.Color(c[0]/255,c[1]/255,c[2]/255).convertSRGBToLinear();
  const m4=(a)=>new THREE.Matrix4().set(a[3],a[4],a[5],a[0],a[6],a[7],a[8],a[1],a[9],a[10],a[11],a[2],0,0,0,1);
  // ------------------------------------------------ materials
  const PAT={Concrete:1,Asphalt:1,Grass:1,Sand:1,Fabric:1,Slate:1,Granite:1,Pebble:1,Ground:1,LeafyGrass:1,Mud:1,Snow:1,Limestone:1,Pavement:1,Basalt:1,Sandstone:1,Rock:1,Salt:1,Cobblestone:2,Brick:3,Wood:4,WoodPlanks:5,DiamondPlate:6,Metal:7,CorrodedMetal:1,Plaster:1,Carpet:1,Rubber:1,Leather:1,CeramicTiles:8,Marble:1,ClayRoofTiles:8,RoofShingles:8};
  const ROUGH={Plastic:.55,SmoothPlastic:.35,Metal:.38,DiamondPlate:.4,CorrodedMetal:.85,Foil:.15,Glass:.05,Ice:.1,Marble:.3,Granite:.8,Neon:1,Wood:.75,WoodPlanks:.75,Rubber:.9,Leather:.6,Fabric:.95,Carpet:.95};
  const METAL={Metal:.6,DiamondPlate:.6,CorrodedMetal:.3,Foil:.9};
  const matCache=new Map();
  function material(c,m,t,r,parts){
    const key=c.join(',')+m+t+r;
    if(matCache.has(key))return matCache.get(key);
    let mat;
    const color=col(c);
    if(m==='Neon'){mat=new THREE.MeshStandardMaterial({color,emissive:color,emissiveIntensity:2.2,roughness:1});}
    else if(m==='Glass'){mat=new THREE.MeshPhysicalMaterial({color,roughness:.05,metalness:0,transparent:true,opacity:Math.max(0.12,(1-t)*0.35),depthWrite:false});}
    else{
      mat=new THREE.MeshStandardMaterial({color,roughness:ROUGH[m]??.8,metalness:METAL[m]??0});
      if(r>0){mat.metalness=Math.min(1,mat.metalness+r);mat.roughness=Math.max(.05,mat.roughness-r*0.8);}
      const pat=PAT[m]||0;
      if(pat){
        mat.onBeforeCompile=(sh)=>{
          sh.uniforms.pat={value:pat};
          sh.vertexShader=sh.vertexShader.replace('#include <common>','#include <common>\nvarying vec3 vW;varying vec3 vN;').replace('#include <worldpos_vertex>','#include <worldpos_vertex>\nvW=(modelMatrix*vec4(transformed,1.0)).xyz;vN=normalize(mat3(modelMatrix)*objectNormal);');
          sh.fragmentShader=sh.fragmentShader.replace('#include <common>',`#include <common>
varying vec3 vW;varying vec3 vN;uniform int pat;
float h(vec3 p){return fract(sin(dot(p,vec3(12.9898,78.233,37.719)))*43758.5453);}
float n3(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
 return mix(mix(mix(h(i),h(i+vec3(1,0,0)),f.x),mix(h(i+vec3(0,1,0)),h(i+vec3(1,1,0)),f.x),f.y),mix(mix(h(i+vec3(0,0,1)),h(i+vec3(1,0,1)),f.x),mix(h(i+vec3(0,1,1)),h(i+vec3(1,1,1)),f.x),f.y),f.z);}
float tri(vec3 p,float s){vec3 a=abs(vN);return (n3(p.yzx*s)*a.x+n3(p.xzy*s)*a.y+n3(p*s)*a.z)/(a.x+a.y+a.z);}
`).replace('#include <color_fragment>',`#include <color_fragment>
{ float v=1.0; vec3 a=abs(vN);
  vec2 uv = a.y>a.x&&a.y>a.z ? vW.xz : (a.x>a.z ? vW.zy : vW.xy);
  if(pat==1){ v=0.86+0.22*tri(vW,1.7)+0.08*tri(vW,7.0);}
  else if(pat==2){ vec2 g=fract(uv*0.6); float e=min(min(g.x,1.-g.x),min(g.y,1.-g.y)); v=(e<0.06?0.6:1.0)*(0.85+0.25*tri(vW,3.0));}
  else if(pat==3){ vec2 b=uv*vec2(1.0,2.4); b.x+=step(1.0,mod(b.y,2.0))*0.5; vec2 g=fract(b); float e=min(min(g.x,1.-g.x)*1.0,min(g.y,1.-g.y)*0.42); v=(e<0.04?0.55:1.0)*(0.88+0.2*h(floor(b).xyy));}
  else if(pat==4){ v=0.8+0.25*sin((uv.x+uv.y*0.05+n3(vW*2.0)*0.6)*28.0)*0.5+0.1*tri(vW,4.0);}
  else if(pat==5){ vec2 b=uv*vec2(0.9,0.4); float g=fract(b.x); v=(g<0.04?0.6:1.0)*(0.78+0.3*h(vec3(floor(b.x),floor(b.y+floor(b.x)*0.37),1.0)))+0.08*sin(uv.y*40.0+n3(vW*3.0)*4.0);}
  else if(pat==6){ vec2 g=fract(uv*1.6); float d=abs(g.x-g.y); v=d<0.12?1.25:0.9;}
  else if(pat==7){ v=0.92+0.12*n3(vec3(uv.x*30.0,uv.y*0.6,0.0));}
  else if(pat==8){ vec2 g=fract(uv*0.75); float e=min(min(g.x,1.-g.x),min(g.y,1.-g.y)); v=e<0.03?0.7:1.0;}
  diffuseColor.rgb*=v; }`);
        };
        mat.customProgramCacheKey=()=>'pat'+pat;
      }
    }
    if(t>0&&m!=='Glass'){mat.transparent=true;mat.opacity=1-t;mat.depthWrite=t<0.5;}
    matCache.set(key,mat);return mat;
  }
  // ------------------------------------------------ geometry
  const geoCache=new Map();
  function wedgeGeo(){const g=new THREE.BufferGeometry();
    const v=[[-.5,-.5,-.5],[.5,-.5,-.5],[.5,-.5,.5],[-.5,-.5,.5],[-.5,.5,.5],[.5,.5,.5]];
    const f=[[0,2,1],[0,3,2],[3,4,5],[3,5,2],[0,1,5],[0,5,4],[0,4,3],[1,2,5]];
    const pos=[];for(const t of f)for(const i of t)pos.push(...v[i]);
    g.setAttribute('position',new THREE.Float32BufferAttribute(pos,3));g.computeVertexNormals();return g;}
  function cornerGeo(){const g=new THREE.BufferGeometry();
    const v=[[-.5,-.5,-.5],[.5,-.5,-.5],[.5,-.5,.5],[-.5,-.5,.5],[.5,.5,-.5]];
    const f=[[0,2,1],[0,3,2],[0,1,4],[1,2,4],[2,3,4],[3,0,4]];
    const pos=[];for(const t of f)for(const i of t)pos.push(...v[i]);
    g.setAttribute('position',new THREE.Float32BufferAttribute(pos,3));g.computeVertexNormals();return g;}
  function geometry(s,z){
    let k=s;let g;
    if(s==='Special:Sphere'){g=geoCache.get('ball')||new THREE.SphereGeometry(.5,24,16);geoCache.set('ball',g);return [g,new THREE.Vector3(...z)];}
    if(s==='Ball'){g=geoCache.get('ball')||new THREE.SphereGeometry(.5,24,16);geoCache.set('ball',g);return [g,new THREE.Vector3(Math.min(...z),Math.min(...z),Math.min(...z))]; }
    if(s==='Cylinder'){g=geoCache.get('cyl')||new THREE.CylinderGeometry(.5,.5,1,28).rotateZ(Math.PI/2);geoCache.set('cyl',g);const r=Math.min(z[1],z[2]);return [g,new THREE.Vector3(z[0],r,r)];}
    if(s==='Special:Cylinder'){g=geoCache.get('cyly')||new THREE.CylinderGeometry(.5,.5,1,28);geoCache.set('cyly',g);return [g,new THREE.Vector3(z[0],z[1],z[2])];}
    if(s==='Wedge'){g=geoCache.get('wedge')||wedgeGeo();geoCache.set('wedge',g);return [g,new THREE.Vector3(...z)];}
    if(s==='CornerWedge'){g=geoCache.get('cw')||cornerGeo();geoCache.set('cw',g);return [g,new THREE.Vector3(...z)];}
    g=geoCache.get('box')||new THREE.BoxGeometry(1,1,1);geoCache.set('box',g);return [g,new THREE.Vector3(...z)];
  }
  function addParts(scene,parts,shadows){
    const byId=new Map();
    for(const p of parts){
      const [g,sc]=geometry(p.s,p.z);
      const mesh=new THREE.Mesh(g,material(p.c,p.m,p.t,p.r));
      const M=m4(p.cf);M.multiply(new THREE.Matrix4().makeScale(sc.x,sc.y,sc.z));
      mesh.matrixAutoUpdate=false;mesh.matrix.copy(M);
      if(shadows&&p.m!=='Neon'&&p.m!=='Glass'&&p.t<0.5){mesh.castShadow=true;mesh.receiveShadow=true;}
      scene.add(mesh);if(p.id)byId.set(p.id,mesh);
    }
    return byId;
  }
  // ------------------------------------------------ scene
  const scene=new THREE.Scene();
  const pm=new THREE.PMREMGenerator(R);scene.environment=pm.fromScene(new RoomEnvironment(),0.04).texture;scene.environmentIntensity=0.55;
  const L=S.lighting;
  const sunDir=new THREE.Vector3(...L.sun).normalize();
  const day=Math.max(0,Math.min(1,(sunDir.y+0.1)*3));
  const skyTop=new THREE.Color().setRGB(0.25+0.15*(1-day),0.45*day+0.08,0.85*day+0.15);
  const skyCol=new THREE.Color(0x87a9d6).lerp(new THREE.Color(0x101828),1-day);
  scene.background=skyCol.clone().convertSRGBToLinear();
  if(L.atm){const ac=col(L.atm.c);scene.fog=new THREE.FogExp2(scene.background.clone().lerp(ac,.5),Math.min(0.02,L.atm.d*0.004));}
  if(L.fogEnd<5000){scene.fog=new THREE.Fog(col(L.fogColor),L.fogStart,L.fogEnd);}
  const amb=col(L.oamb).multiplyScalar(0.9).add(col(L.amb).multiplyScalar(0.6));
  scene.add(new THREE.HemisphereLight(skyCol.clone().convertSRGBToLinear().lerp(new THREE.Color(1,1,1),.3),new THREE.Color(0x4a4036).convertSRGBToLinear(),0.55*(L.bright/2)+amb.r*0.5));
  scene.add(new THREE.AmbientLight(amb,0.35));
  const camM=m4(S.camera.cf);
  const cam=new THREE.PerspectiveCamera(S.camera.fov,W/H,0.1,5000);
  cam.matrixAutoUpdate=false;cam.matrix.copy(camM);cam.matrixWorld.copy(camM);cam.matrixWorldInverse.copy(camM).invert();
  const camPos=new THREE.Vector3().setFromMatrixPosition(camM);
  const look=new THREE.Vector3(0,0,-1).applyMatrix4(new THREE.Matrix4().extractRotation(camM));
  if(sunDir.y>0){
    const sun=new THREE.DirectionalLight(0xfff4e0,2.1*(L.bright/2)*day);
    const focus=camPos.clone().add(look.clone().multiplyScalar(40));
    sun.position.copy(focus.clone().add(sunDir.clone().multiplyScalar(300)));sun.target.position.copy(focus);
    sun.castShadow=true;sun.shadow.mapSize.set(4096,4096);const sc=sun.shadow.camera;sc.left=-90;sc.right=90;sc.top=90;sc.bottom=-90;sc.near=1;sc.far=800;sun.shadow.bias=-0.0005;sun.shadow.normalBias=0.05;
    scene.add(sun);scene.add(sun.target);
  }
  const byId=addParts(scene,S.parts,true);
  // terrain
  const TC={Grass:[80,124,58],Water:[40,90,140],Sand:[200,180,130],Rock:[110,110,110],Mud:[90,70,50],Ground:[110,90,60],Asphalt:[60,60,60],Concrete:[130,130,130],LeafyGrass:[70,120,50],Snow:[240,240,250]};
  for(const t of S.terrain){
    const c=TC[t.m]||[120,120,120];
    const geo=t.k==='ball'?new THREE.SphereGeometry(.5,20,14):(t.k==='cyl'?new THREE.CylinderGeometry(.5,.5,1,32):new THREE.BoxGeometry(1,1,1));
    const mat=t.m==='Water'?new THREE.MeshStandardMaterial({color:col(c),roughness:.08,metalness:.1,transparent:true,opacity:.8}):material(c,t.m==='Grass'?'Grass':'Concrete',0,0);
    const mesh=new THREE.Mesh(geo,mat);const M=m4(t.cf);M.multiply(new THREE.Matrix4().makeScale(...t.size));mesh.matrixAutoUpdate=false;mesh.matrix.copy(M);mesh.receiveShadow=true;scene.add(mesh);
  }
  // lights: the nearest ones to the camera
  const ls=S.lights.map(l=>({...l,d:new THREE.Vector3(l.cf[0],l.cf[1],l.cf[2]).distanceTo(camPos)})).sort((a,b)=>a.d-b.d).slice(0,28);
  const FACE={Front:[0,0,-1],Back:[0,0,1],Top:[0,1,0],Bottom:[0,-1,0],Left:[-1,0,0],Right:[1,0,0]};
  let shadowsLeft=4;
  for(const l of ls){
    const c=col(l.c);const M=m4(l.cf);const p=new THREE.Vector3().setFromMatrixPosition(M);
    const inten=l.b*Math.min(60,l.r*l.r*0.35+4);
    if(l.k==='PointLight'){const pl=new THREE.PointLight(c,inten,l.r*1.6,1.6);pl.position.copy(p);if(l.sh&&shadowsLeft-->0){pl.castShadow=true;pl.shadow.mapSize.set(512,512);}scene.add(pl);}
    else{
      const f=FACE[l.face||'Front'];const dir=new THREE.Vector3(...f).applyMatrix4(new THREE.Matrix4().extractRotation(M)).normalize();
      if(l.k==='SurfaceLight'){p.add(dir.clone().multiplyScalar(Math.abs(f[0])*l.size[0]/2+Math.abs(f[1])*l.size[1]/2+Math.abs(f[2])*l.size[2]/2+0.05));}
      const sl=new THREE.SpotLight(c,inten*1.5,l.r*1.6,Math.min(Math.PI/2.05,THREE.MathUtils.degToRad((l.a||90)/2+10)),0.6,1.4);
      sl.position.copy(p);sl.target.position.copy(p.clone().add(dir));
      if(l.sh&&shadowsLeft-->0){sl.castShadow=true;sl.shadow.mapSize.set(1024,1024);}
      scene.add(sl);scene.add(sl.target);
    }
  }
  // highlights
  for(const h of S.hl){
    for(const id of h.ids){const m=byId.get(id);if(!m)continue;
      if(h.ft<1){const f=new THREE.Mesh(m.geometry,new THREE.MeshBasicMaterial({color:col(h.fill),transparent:true,opacity:1-h.ft,depthTest:false}));f.matrixAutoUpdate=false;f.matrix.copy(m.matrix);f.renderOrder=10;scene.add(f);}
      if(h.ot<1){const e=new THREE.LineSegments(new THREE.EdgesGeometry(m.geometry,30),new THREE.LineBasicMaterial({color:col(h.out),transparent:true,opacity:1-h.ot,depthTest:false}));e.matrixAutoUpdate=false;e.matrix.copy(m.matrix);e.renderOrder=11;scene.add(e);}
    }
  }
  // smoke/sparks
  for(const f of S.fx){const sp=new THREE.Sprite(new THREE.SpriteMaterial({color:col(f.c),transparent:true,opacity:.35}));sp.position.set(...f.p);const s=Math.max(.3,f.size*2);sp.scale.set(s,s,s);scene.add(sp);}
  // surface guis -> canvas textures on the part face
  for(const sg of S.surf){
    const cv=document.createElement('canvas');const sc=Math.min(1,1024/Math.max(sg.pw,sg.ph));cv.width=Math.max(2,Math.round(sg.pw*sc));cv.height=Math.max(2,Math.round(sg.ph*sc));
    const ctx=cv.getContext('2d');ctx.scale(sc,sc);for(const e of sg.els)draw2d(ctx,e);
    const tex=new THREE.CanvasTexture(cv);tex.colorSpace=THREE.SRGBColorSpace;
    const f=FACE[sg.face];const z=sg.size;
    let w,h;if(sg.face==='Front'||sg.face==='Back'){w=z[0];h=z[1];}else if(sg.face==='Left'||sg.face==='Right'){w=z[2];h=z[1];}else{w=z[0];h=z[2];}
    const plane=new THREE.Mesh(new THREE.PlaneGeometry(w,h),new THREE.MeshBasicMaterial({map:tex,transparent:true,toneMapped:!sg.glow}));
    const M=m4(sg.cf);const off=new THREE.Matrix4();
    const d=0.02+(Math.abs(f[0])*z[0]+Math.abs(f[1])*z[1]+Math.abs(f[2])*z[2])/2;
    const rot={Front:new THREE.Euler(0,Math.PI,0),Back:new THREE.Euler(0,0,0),Right:new THREE.Euler(0,Math.PI/2,0),Left:new THREE.Euler(0,-Math.PI/2,0),Top:new THREE.Euler(-Math.PI/2,0,0),Bottom:new THREE.Euler(Math.PI/2,0,0)}[sg.face];
    off.makeRotationFromEuler(rot);off.setPosition(f[0]*d,f[1]*d,f[2]*d);
    plane.matrixAutoUpdate=false;plane.matrix.copy(M.multiply(off));scene.add(plane);
  }
  R.render(scene,cam);
  // ------------------------------------------------ 2D GUI
  function css(c,t){return `rgba(${c[0]},${c[1]},${c[2]},${1-(t??0)})`;}
  function weight(e){if(e.fw){return {Thin:100,ExtraLight:200,Light:300,Regular:400,Medium:500,SemiBold:600,Bold:700,ExtraBold:800,Heavy:900}[e.fw]||400;}return FONT[e.font]||'400';}
  function rich(s){return s.replace(/&/g,'&amp;').replace(/<(?!\/?(b|i|u|s|font|br)\b)/g,'&lt;').replace(/<font color="#?([0-9a-fA-F]{6})">/g,'<span style="color:#$1">').replace(/<font color="rgb\((\d+),(\d+),(\d+)\)">/g,'<span style="color:rgb($1,$2,$3)">').replace(/<font[^>]*>/g,'<span>').replace(/<\/font>/g,'</span>').replace(/<br\s*\/?>/g,'\n');}
  function htmlEl(e,root,ox,oy){
    const d=document.createElement('div');d.className='g';
    d.style.left=(e.x-ox)+'px';d.style.top=(e.y-oy)+'px';d.style.width=Math.max(0,e.w)+'px';d.style.height=Math.max(0,e.h)+'px';
    if(e.bgt<1){
      if(e.grad){const stops=e.grad.c.map(k=>`rgb(${k[1][0]*(e.bg[0]/255)},${k[1][1]*(e.bg[1]/255)},${k[1][2]*(e.bg[2]/255)}) ${k[0]*100}%`).join(',');d.style.background=`linear-gradient(${90+e.grad.rot}deg,${stops})`;d.style.opacity=1-e.bgt;}
      else d.style.background=css(e.bg,e.bgt);
    }
    if(e.corner)d.style.borderRadius=e.corner+'px';
    if(e.stroke&&e.stroke[2]<1)d.style.boxShadow=`0 0 0 ${e.stroke[1]}px ${css(e.stroke[0],e.stroke[2])}`;
    if(e.rot)d.style.transform=`rotate(${e.rot}deg)`;
    if(e.img&&e.it<1){const im=document.createElement('div');im.style.cssText='position:absolute;inset:0;border-radius:inherit;background:repeating-linear-gradient(45deg,rgba(255,255,255,.08) 0 6px,rgba(255,255,255,.02) 6px 12px)';d.appendChild(im);}
    if(e.text!==undefined&&e.text!==''&&e.tt<1){
      const t=document.createElement('div');t.className='t';
      t.style.color=css(e.tc,e.tt);t.style.fontSize=e.ts+'px';t.style.fontWeight=weight(e);
      t.style.justifyContent={Left:'flex-start',Center:'center',Right:'flex-end'}[e.xa];
      t.style.alignItems={Top:'flex-start',Center:'center',Bottom:'flex-end'}[e.ya];
      t.style.textAlign={Left:'left',Center:'center',Right:'right'}[e.xa];
      t.style.whiteSpace=e.wrap?'pre-wrap':'pre';
      if(e.tst<1)t.style.webkitTextStroke=`1px ${css(e.tsc,e.tst)}`;
      if(e.tstroke&&e.tstroke[2]<1)t.style.textShadow=`0 0 ${e.tstroke[1]+1}px ${css(e.tstroke[0],e.tstroke[2])}`;
      const sp=document.createElement('span');if(e.rich)sp.innerHTML=rich(e.text);else sp.textContent=e.text;t.appendChild(sp);d.appendChild(t);
    }
    if(e.clip){const c=e.clip;const wrap=document.createElement('div');wrap.style.cssText=`position:absolute;overflow:hidden;left:${c[0]-ox}px;top:${c[1]-oy}px;width:${c[2]-c[0]}px;height:${c[3]-c[1]}px`;d.style.left=(e.x-c[0])+'px';d.style.top=(e.y-c[1])+'px';wrap.appendChild(d);root.appendChild(wrap);}
    else root.appendChild(d);
    if(e.vp)viewports.push({e,ox,oy,clip:e.clip});
  }
  function draw2d(ctx,e){
    ctx.save();
    if(e.clip){ctx.beginPath();ctx.rect(e.clip[0],e.clip[1],e.clip[2]-e.clip[0],e.clip[3]-e.clip[1]);ctx.clip();}
    const r=e.corner||0;
    if(e.bgt<1){ctx.fillStyle=css(e.bg,e.bgt);ctx.beginPath();ctx.roundRect?ctx.roundRect(e.x,e.y,e.w,e.h,r):ctx.rect(e.x,e.y,e.w,e.h);ctx.fill();}
    if(e.stroke&&e.stroke[2]<1){ctx.strokeStyle=css(e.stroke[0],e.stroke[2]);ctx.lineWidth=e.stroke[1];ctx.beginPath();ctx.roundRect?ctx.roundRect(e.x,e.y,e.w,e.h,r):ctx.rect(e.x,e.y,e.w,e.h);ctx.stroke();}
    if(e.text&&e.tt<1){ctx.fillStyle=css(e.tc,e.tt);let fs=e.ts;ctx.font=`${weight(e)} ${fs}px Arial`;const longest=String(e.text).replace(/<[^>]+>/g,'').split('\n').reduce((a,b)=>b.length>a.length?b:a,'');while(fs>6&&ctx.measureText(longest).width>e.w-4){fs-=2;ctx.font=`${weight(e)} ${fs}px Arial`;}e={...e,ts:fs};ctx.textBaseline='middle';
      const xa=e.xa||'Center';ctx.textAlign=xa==='Left'?'left':(xa==='Right'?'right':'center');
      const tx=xa==='Left'?e.x+2:(xa==='Right'?e.x+e.w-2:e.x+e.w/2);
      const lines=String(e.text).replace(/<[^>]+>/g,'').split('\n');const lh=e.ts*1.1;let y0=e.y+e.h/2-(lines.length-1)*lh/2;
      if(e.ya==='Top')y0=e.y+lh/2;else if(e.ya==='Bottom')y0=e.y+e.h-(lines.length-0.5)*lh;
      lines.forEach((ln,i)=>ctx.fillText(ln,tx,y0+i*lh));}
    ctx.restore();
  }
  const ui=document.getElementById('ui');ui.style.width=W+'px';ui.style.height=H+'px';
  const viewports=[];
  // roblox top bar
  const tb=document.createElement('div');tb.className='top';ui.appendChild(tb);
  for(const x of [12,62]){const b=document.createElement('div');b.className='rb';b.style.left=x+'px';tb.appendChild(b);}
  if(S.coreGui.PlayerList!==false){const b=document.createElement('div');b.className='rb';b.style.right='12px';tb.appendChild(b);}
  for(const b of S.bill.sort((a,b)=>b.z-a.z))for(const e of b.els)htmlEl(e,ui,0,0);
  for(const p of S.prompts){const d=document.createElement('div');d.className='pr';d.style.left=p.x+'px';d.style.top=p.y+'px';d.innerHTML=`<div class="k">${p.key}</div><div>${p.o?`<div class="o">${p.o}</div>`:''}<div>${p.a}</div></div>`;ui.appendChild(d);}
  for(const e of S.gui)htmlEl(e,ui,0,0);
  // viewport frames: render their parts into small canvases
  for(const v of viewports){
    const e=v.e;if(!e.vp.cam||e.w<4||e.h<4)continue;
    const cv=document.createElement('canvas');cv.width=Math.round(e.w);cv.height=Math.round(e.h);cv.style.cssText=`position:absolute;left:${e.x}px;top:${e.y}px;width:${e.w}px;height:${e.h}px;border-radius:${e.corner||0}px`;
    const r2=new THREE.WebGLRenderer({canvas:cv,antialias:true,alpha:true,preserveDrawingBuffer:true});r2.setSize(e.w,e.h,false);r2.outputColorSpace=THREE.SRGBColorSpace;r2.toneMapping=THREE.ACESFilmicToneMapping;
    const s2=new THREE.Scene();addParts(s2,e.vp.parts,false);
    s2.add(new THREE.AmbientLight(col(e.vp.amb),1.2));const dl=new THREE.DirectionalLight(col(e.vp.lc),2.2);dl.position.set(-e.vp.ld[0],-e.vp.ld[1],-e.vp.ld[2]);s2.add(dl);
    const dl2=new THREE.DirectionalLight(0xffffff,0.8);dl2.position.set(1,0.5,1);s2.add(dl2);
    const c2=new THREE.PerspectiveCamera(e.vp.cam.fov,e.w/e.h,0.05,500);const cm=m4(e.vp.cam.cf);c2.matrixAutoUpdate=false;c2.matrix.copy(cm);c2.matrixWorld.copy(cm);c2.matrixWorldInverse.copy(cm).invert();
    r2.render(s2,c2);
    if(v.clip){const c=v.clip;const wrap=document.createElement('div');wrap.style.cssText=`position:absolute;overflow:hidden;left:${c[0]}px;top:${c[1]}px;width:${c[2]-c[0]}px;height:${c[3]-c[1]}px`;cv.style.left=(e.x-c[0])+'px';cv.style.top=(e.y-c[1])+'px';wrap.appendChild(cv);ui.appendChild(wrap);}
    else ui.appendChild(cv);
  }
  // cursor
  const cur=document.createElement('div');cur.style.cssText=`position:absolute;left:${S.mouse[0]}px;top:${S.mouse[1]}px;width:0;height:0;border-left:7px solid transparent;border-right:7px solid transparent;border-bottom:16px solid #fff;transform:rotate(-30deg);transform-origin:0 0;filter:drop-shadow(0 0 1px #000)`;ui.appendChild(cur);
  return true;
};
window.ready=true;
