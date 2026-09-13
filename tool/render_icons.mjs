// Raster exports of the code-native geometric icon in Android's ic_launcher.xml.
// No remote artwork or missing binary assets are required.
import fs from 'node:fs';
import zlib from 'node:zlib';
const ink = [17,19,17], gold = [184,173,137];
function inPoly(x,y,p) { let inside=false; for(let i=0,j=p.length-1;i<p.length;j=i++) { const a=p[i],b=p[j]; if(((a[1]>y)!=(b[1]>y))&&(x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0])) inside=!inside; } return inside; }
const mountain=[[33,64],[48,45],[60,59],[68,51],[82,74],[33,74]];
function crc(b) { let c=0xffffffff; for(const byte of b){ c^=byte;for(let j=0;j<8;j++)c=(c>>>1)^((c&1)?0xedb88320:0); } return (c^0xffffffff)>>>0; }
function chunk(t,b){const type=Buffer.from(t), n=Buffer.alloc(4), c=Buffer.alloc(4);n.writeUInt32BE(b.length);c.writeUInt32BE(crc(Buffer.concat([type,b])));return Buffer.concat([n,type,b,c]);}
function png(n){const data=Buffer.alloc(n*(1+n*3));for(let y=0;y<n;y++)for(let x=0;x<n;x++){const X=(x+.5)*108/n,Y=(y+.5)*108/n;let c=ink;if((X>=26&&X<88&&Y>=22&&Y<84)||(X>=18&&X<23&&Y>=32&&Y<96)||(X>=18&&X<81&&Y>=91&&Y<96))c=gold;if(inPoly(X,Y,mountain))c=ink;const off=y*(1+n*3)+1+x*3;data.set(c,off);}const h=Buffer.alloc(13);h.writeUInt32BE(n,0);h.writeUInt32BE(n,4);h[8]=8;h[9]=2;return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',h),chunk('IDAT',zlib.deflateSync(data)),chunk('IEND',Buffer.alloc(0))]);}
const base='ios/Runner/Assets.xcassets';
for(const image of JSON.parse(fs.readFileSync(base+'/AppIcon.appiconset/Contents.json')).images){const n=Math.round(parseFloat(image.size)*parseFloat(image.scale));fs.writeFileSync(base+'/AppIcon.appiconset/'+image.filename,png(n));}
for(const image of JSON.parse(fs.readFileSync(base+'/LaunchImage.imageset/Contents.json')).images)fs.writeFileSync(base+'/LaunchImage.imageset/'+image.filename,png(108*parseFloat(image.scale)));
console.log('Exported iOS icon and launch assets.');
