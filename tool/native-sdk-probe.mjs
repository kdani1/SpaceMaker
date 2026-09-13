// Downloads pinned vendor build inputs for diagnosis only. Does NOT alter the
// installed builder, its coordinate allowlist, Pub packages or app features.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
const output = path.resolve('.tools/native-sdk-probe');
const inputs = [
  ['https://dl.google.com/dl/android/maven2', 'com.google.android.libraries.ads.mobile.sdk', 'ads-mobile-sdk', '1.3.1', 'alternative_next_gen'],
  ['https://dl.google.com/dl/android/maven2', 'com.google.android.gms', 'play-services-ads', '25.4.0', 'default_ads_sdk'],
  ['https://dl.google.com/dl/android/maven2', 'com.google.android.ump', 'user-messaging-platform', '4.0.0', 'privacy'],
  ['https://repo.maven.apache.org/maven2', 'com.revenuecat.purchases', 'purchases-hybrid-common', '18.37.0', 'billing_bridge'],
];
const maxBytes=80*1024*1024;
async function download(url) {
  const res=await fetch(url,{signal:AbortSignal.timeout(90000)});
  if(!res.ok) throw Error(`HTTP ${res.status}: ${url}`);
  if(Number(res.headers.get('content-length'))>maxBytes)throw Error('Artifact exceeds 80 MiB bound');
  const chunks=[];let bytes=0;
  for await(const chunk of res.body){bytes+=chunk.length;if(bytes>maxBytes)throw Error('Artifact exceeds 80 MiB bound');chunks.push(chunk);}
  return Buffer.concat(chunks);
}
await fs.mkdir(output,{recursive:true});
const report=[];
for(const [repo,group,name,version,role] of inputs){
  const coordinate=`${group}:${name}:${version}`;
  const base=`${repo}/${group.replaceAll('.','/')}/${name}/${version}/${name}-${version}`;
  const entry={coordinate,role};
  try {
    const pom=await download(base+'.pom');
    await fs.writeFile(path.join(output,`${name}-${version}.pom`),pom);
    const packaging=pom.toString().match(/<packaging>\s*([^<]+)\s*<\/packaging>/)?.[1]?.trim() ?? 'jar';
    if(!['aar','jar'].includes(packaging))throw Error(`Unsupported probe packaging: ${packaging}`);
    const url=base+'.'+packaging;
    const artifact=await download(url);
    const published=(await download(url+'.sha1')).toString().trim().split(/\s+/)[0].toLowerCase();
    const sha1=crypto.createHash('sha1').update(artifact).digest('hex');
    if(!/^[a-f0-9]{40}$/.test(published)||published!==sha1)throw Error('Vendor checksum mismatch');
    const filename=`${name}-${version}.${packaging}`;
    await fs.writeFile(path.join(output,filename),artifact);
    Object.assign(entry,{status:'downloaded_not_installed',url,filename,bytes:artifact.length,repositorySha1Matched:true,sha256:crypto.createHash('sha256').update(artifact).digest('hex')});
    console.log(`${coordinate}: ${(artifact.length/1024/1024).toFixed(2)} MiB, repository SHA-1 matches; SHA-256 recorded`);
  }catch(error){entry.status='failed';entry.error=String(error.message);console.log(`${coordinate}: ${entry.error}`);}
  report.push(entry);
}
await fs.writeFile(path.join(output,'report.json'),JSON.stringify({checkedAt:new Date().toISOString(),note:'Direct artifacts only, not a resolved transitive graph or an installable SDK.',artifacts:report},null,2)+'\n');
if(report.some(r=>r.status==='failed'))process.exitCode=1;
